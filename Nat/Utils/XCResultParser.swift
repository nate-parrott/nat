import Foundation

enum XCResultError: Error {
    case noData
    case decodingFailed
    case processError(String)
}

func parseXCResult(url: URL) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = ["xcresulttool", "get", "test-results", "summary", "--path", url.path]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    
    return try await withCheckedThrowingContinuation { continuation in
        do {
            try process.run()
            Task {
                do {
                    guard let data = try pipe.fileHandleForReading.readToEnd() else {
                        continuation.resume(throwing: XCResultError.noData)
                        return
                    }
                    process.waitUntilExit()
                    
                    guard let text = String(data: data, encoding: .utf8) else {
                        continuation.resume(throwing: XCResultError.decodingFailed)
                        return
                    }
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: XCResultError.processError(error.localizedDescription))
                }
            }
        } catch {
            continuation.resume(throwing: XCResultError.processError(error.localizedDescription))
        }
    }
}
