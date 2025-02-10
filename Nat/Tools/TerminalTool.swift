import Foundation
import ChatToys

extension URL {
    // Escapes spaces with backslashes
    var filePathEscapedForTerminal: String {
        // Written by Phil
        return self.path.replacingOccurrences(of: " ", with: "\\ ")
    }
}

extension String {
    // truncateMiddle(firstNLines: 4, lastNLines: 20)
    func truncateMiddle(firstNLines: Int, lastNLines: Int) -> String {
        // Written by Phil
        let lines = self.components(separatedBy: "\n")
        guard lines.count > firstNLines + lastNLines else { return String(self) }

        let firstLines = lines.prefix(firstNLines).joined(separator: "\n")
        let lastLines = lines.suffix(lastNLines).joined(separator: "\n")

        return firstLines + "\n...\n" + lastLines
    }
}

private enum TerminalToolError: Error {
    case noDocument
}

struct TerminalTool: Tool {
    var functions: [LLMFunction] {
        [Self.fn.asLLMFunction]
    }
    
    static let fn = TypedFunction<Args>(name: "terminal", description: """
        Execute a terminal command and return its output. 
        Only use this for commands that will complete quickly (within 10 minutes) like running tests, interacting with git, etc. 
        NEVER use for long-running or indefinite programs like servers, processes, interactive programs.
        Always add -y or --yes flags when available to avoid prompts and interactivity.
        Use --no-pager for git show and related ops.
        """, type: Args.self)
    
    struct Args: FunctionArgs {
        var command: String
        
        static var schema: [String: LLMFunction.JsonSchema] {
            [
                "command": .string(description: "The shell command to execute")
            ]
        }
    }
    
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse? {
        guard let args = Self.fn.checkMatch(call: call) else { return nil }
        
        let command = args.command
        await context.log(.terminal(command: "\(command)"))

        guard let activeDirectory = context.activeDirectory else {
            return call.response(text: "No active directory selected")
        }

        guard let document = context.document else {
            throw TerminalToolError.noDocument
        }

        if await !context.autorun(), await !Alerts.showAppConfirmationDialog(title: "Run terminal command?", message: "Would run \(command) in \(activeDirectory.path())", yesTitle: "Run", noTitle: "Deny") {
            return call.response(text: "User blocked this command from running. Take a beat and ask them what they want to do.")
        }

        do {
            let output = try await runCommand(command, in: activeDirectory, document: document)
            print("<💻 TERMINAL OUTPUT command='\(command)'>")
            print(output)
            print("</TERMINAL OUTPUT>")
            return call.response(text: output.truncateHeadWithEllipsis(chars: 3000))
        } catch {
            return call.response(text: "Error running command: \(error)")
        }
    }

    @MainActor
    private func runCommand(_ command: String, in directory: URL, document: Document) async throws -> String {
//        let finalCmd = "cd \(directory.filePathEscapedForTerminal) && \(command)"
        let output = try await document.getOrCreateTerminal().runAndWaitForOutput(command: command)
        return output.truncateMiddle(firstNLines: 8, lastNLines: 30)
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
