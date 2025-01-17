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
        Always add -y or --yes flags when available to avoid prompts.
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
            return call.response(text: output.truncateHeadWithEllipsis(chars: 3000))
        } catch {
            return call.response(text: "Error running command: \(error)")
        }
    }

    @MainActor
    private func runCommand(_ command: String, in directory: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

//        var collectedOutput = ""
//
//        // Set up async reading of both pipes
//        let outputTask = Task.detached {
//            for try await line in outputPipe.fileHandleForReading.bytes.lines {
//                print("[💾 stdout]", line)  // Print in real time
//                collectedOutput += line + "\n"
//            }
//        }
//
//        let errorTask = Task.detached {
//            for try await line in errorPipe.fileHandleForReading.bytes.lines {
//                print("[💾 stderr]", line)  // Print errors in real time
//                collectedOutput += "Error: " + line + "\n"
//            }
//        }

        var outputData = Data()
        var errorData = Data()

        // Set up async reading of the output pipe
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                DispatchQueue.main.async {
                    outputData.append(data)
                }
            }
        }

        // Set up async reading of the error pipe
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                DispatchQueue.main.async {
                    errorData.append(data)
                }
            }
        }

        try process.run()

        // Set up timeout and cancellation checking
        let monitorTask = Task {
            while true {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                if Task.isCancelled {
                    process.terminate()
                    throw CancellationError()
                }
            }
        }

        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 600_000_000_000)
            process.terminate()
        }

        await process.waitUntilExitAsync()
        try await Task.sleep(seconds: 0.1) // HACK to wait for reads to finish

        // Clean up all monitoring tasks
        monitorTask.cancel()
        timeoutTask.cancel()
//        outputTask.cancel()
//        errorTask.cancel()

        return String(data: outputData, encoding: .utf8) ?? ""
    }
}

enum CommandError: Error {
    case timeout
    case cancelled
}

extension DispatchQueue {
    static let processAwaitQueue = DispatchQueue(label: "ProcessWaiter", qos: .default, attributes: .concurrent)
}

extension Process {
    func waitUntilExitAsync() async {
        await withCheckedContinuation { cont in
            DispatchQueue.processAwaitQueue.async {
                self.waitUntilExit()
                cont.resume(returning: ())
            }
        }
    }
}
