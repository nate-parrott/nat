import Foundation

public extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}

public extension DispatchQueue {
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
