import Foundation

enum SyntaxCheckResult {
    case ok
    case failed(String)
}

/// Checks Swift code for syntax errors and returns a human-readable error message if found
func checkSwiftSyntax(code: String) async -> SyntaxCheckResult {
    do {
        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("temp_\(UUID().uuidString).swift")
        try code.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
        process.arguments = ["-parse", tempFile.path]
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.run()
        
        // Read error output if any
        if let errorData = try errorPipe.fileHandleForReading.readToEnd(),
           let errorStr = String(data: errorData, encoding: .utf8),
           !errorStr.isEmpty {
            process.waitUntilExit()
            return .failed(errorStr)
        }
        
        process.waitUntilExit()
        return process.terminationStatus == 0 ? .ok : .failed("Syntax check failed")
    } catch {
        return .failed("Failed to run syntax check: \(error.localizedDescription)")
    }
}
