import Foundation

extension DispatchQueue {
    func performAsyncThrowing<Result>(_ block: @escaping () throws -> Result) async throws -> Result {
        try await withCheckedThrowingContinuation { cont in
            self.async {
                do {
                    let result = try block()
                    cont.resume(returning: result)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func performAsync<Result>(_ block: @escaping () -> Result) async -> Result {
        await withCheckedContinuation { cont in
            self.async {
                let result = block()
                cont.resume(returning: result)
            }
        }
    }
}

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}

// Based on https://www.swiftbysundell.com/articles/async-and-concurrent-forEach-and-map/
extension Sequence {
    func concurrentMapThrowing<T>(
        _ transform: @escaping (Element) async throws -> T
    ) async throws -> [T] {
        let tasks = map { element in
            Task {
                try await transform(element)
            }
        }

        return try await tasks.asyncMapThrowing { task in
            try await task.value
        }
    }

    private func asyncMapThrowing<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }

    func concurrentMap<T>(
        _ transform: @escaping (Element) async -> T
    ) async -> [T] {
        let tasks = map { element in
            Task {
                await transform(element)
            }
        }

        return await tasks.asyncMap { task in
            await task.value
        }
    }

    func asyncMap<T>(
        _ transform: (Element) async -> T
    ) async -> [T] {
        var values = [T]()

        for element in self {
            await values.append(transform(element))
        }

        return values
    }

    func asyncThrowingMap<T>(
        _ transform: (Element) async throws -> T
    ) async throws -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }
}


// https://stackoverflow.com/questions/75019438/swift-have-a-timeout-for-async-await-function

// TODO: Does this work?
func withTimeout<T>(_ duration: TimeInterval, work: @escaping () async throws -> T) async throws -> T {
    let workTask = Task {
          let taskResult = try await work()
          try Task.checkCancellation()
          return taskResult
      }

      let timeoutTask = Task {
          try await Task.sleep(seconds: duration)
          workTask.cancel()
      }

    do {
        let result = try await workTask.value
        timeoutTask.cancel()
        return result
    } catch {
        if (error as? CancellationError) != nil {
            throw TimeoutErrors.timeoutElapsed
        } else {
            throw error
        }
    }
}

enum TimeoutErrors: Error {
    case timeoutElapsed
}
