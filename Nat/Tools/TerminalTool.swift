import Foundation
import ChatToys

struct TerminalTool: Tool {
    var functions: [LLMFunction] {
        [fn.asLLMFunction]
    }
    
    let fn = TypedFunction<Args>(name: "terminal", description: """
        Execute a terminal command and return its output. 
        Only use this for commands that will complete quickly (within 10 minutes) like running tests, interacting with git, etc. 
        NEVER use for long-running or indefinite programs like servers, processes, interactive programs.
        Always add -y or --yes flags when available to avoid prompts. Use quiet/minimal output flags when available (e.g. --quiet for build commands).
        """, type: Args.self)
    
    struct Args: FunctionArgs {
        var command: String
        
        static var schema: [String: LLMFunction.JsonSchema] {
            [
                "command": .string(description: "The shell command to execute")
            ]
        }
    }
    
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> LLMMessage.FunctionResponse? {
        guard let args = fn.checkMatch(call: call) else { return nil }
        
        let command = args.command
        context.log(.terminal(command: "\(command)"))

        guard let activeDirectory = context.activeDirectory else {
            return call.response(text: "No active directory selected")
        }

        if context.confirmTerminalCommands, await !Alerts.showAppConfirmationDialog(title: "Run terminal command?", message: "Would run \(command) in \(activeDirectory.path())", yesTitle: "Run", noTitle: "Deny") {
            return call.response(text: "User blocked this command from running. Take a beat and ask them what they want to do.")
        }

        do {
            let output = try await runCommand(command, in: activeDirectory)
            return call.response(text: output)
        } catch {
            return call.response(text: "Error running command: \(error)")
        }
    }
    
    private func runCommand(_ command: String, in directory: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        
        // Set up timeout and cancellation checking
        let task = Task {
            while true {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second intervals
                if Task.isCancelled {
                    process.terminate()
                    throw CancellationError()
                }
            }
        }
        
        // Wait for process with timeout
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 600_000_000_000) // 10 minutes
            process.terminate()
        }
        
        process.waitUntilExit()
        
        // Clean up monitoring tasks
        task.cancel()
        timeoutTask.cancel()
        
        let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
        let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        return output + error
    }
}

enum CommandError: Error {
    case timeout
    case cancelled
}
