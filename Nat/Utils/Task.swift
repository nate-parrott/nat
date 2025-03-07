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

// Extension that adds throttling capability to AsyncSequence
extension AsyncSequence {
    /// Throttles the elements from this sequence, allowing at most one element to be emitted 
    /// per specified time interval.
    ///
    /// - Parameter interval: The minimum time interval between emitted elements
    /// - Returns: An AsyncStream that emits elements with the specified throttling applied
    func throttle(for interval: TimeInterval) -> AsyncThrowingStream<Element, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var lastEmissionTime: Date?
                var lastElement: Element?
                
                do {
                    for try await element in self {
                        let now = Date()
                        
                        // Store this as the last element regardless
                        lastElement = element
                        
                        // Check if we should emit based on time elapsed since last emission
                        if let lastTime = lastEmissionTime {
                            let elapsed = now.timeIntervalSince(lastTime)
                            
                            if elapsed < interval {
                                // Skip this element as not enough time has passed
                                continue
                            }
                        }
                        
                        // Emit the element and update the last emission time
                        lastEmissionTime = now
                        continuation.yield(element)
                        lastElement = nil // Element was emitted, so clear it
                    }
                    
                    // Ensure we emit the last element if it wasn't emitted yet
                    if let finalElement = lastElement {
                        continuation.yield(finalElement)
                    }
                    
                    continuation.finish()
                } catch {
                    if !(error is CancellationError) {
                        continuation.finish(throwing: error)
                    } else {
                        continuation.finish()
                    }
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }.asStream
    }
}

