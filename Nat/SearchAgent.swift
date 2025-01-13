import ChatToys
import Foundation

func codeSearch(prompt: String, folderURL: URL) async throws -> String {
    let agent = EphemeralAgent(model: .init())
    let fileTree = FileTree.fullTree(url: folderURL) // Just use whole tree
    let systemPrompt = """
    Act as an expert engineer pair-programming with another engineer in an unfamiliar codebase.
    The other programmer will write the code, but they can only read parts of the codebase that you provide to them.
    They have passed you a question or topic, relevant to a coding task they're doing.
    It is your job to dive into the codebase and bring them snippets of code that they'll be able to use.
    You will be evaluated on the comprehensiveness of the snippets you provide, and the signal to noise ratio; don't make them sift through too much junk.
    
    You should return snippets containing:
    - All the functions they will need to read and modify
    - Function definitions for relevant types
    - Examples of other places in the codebase where related tasks are done, so they can understand the patterns used
    - Relevant documentation
    
    To perform this, review the file tree and use your tools to read the most-likely-relevant files.
    Then, look at their contents to determine whether they're relevant, which lines are relevant, and any other information you need.
    For example, you might discover that the file you looked at calls out to another function that seems relevant, so find that one too.
    If you don't know where to look, review a few of the most relevant-sounding files.
    
    You are limited to 3 steps of execution, so you should read several files (up to 10) in parallel by using multiple function calls at once.
    When you're done, call your finish function with a list of paths and snippets to provide to your engineer.
    
    [BEGIN FILE TREE]
    \(fileTree)
    [END FILE TREE]
    
    [[CONTEXT]]
    
    Next, the engineer will provide their search prompt:
    """

    print("[🔎 CodeSearch] File tree: \n\(fileTree)")

    let codeSearchFinishTool = TypedFunction(name: "finish", description: "Call this to provide your answer snippets", type: CodeSearchFinishFunctionArgs.self)

    guard let finish = try await agent.send(
        message: LLMMessage(role: .user, content: prompt),
        llm: LLMs.quickModel(),
        tools: [FileReaderTool()],
        systemPrompt: systemPrompt,
        agentName: "🔎 CodeSearch",
        folderURL: folderURL,
        maxIterations: 5,
        finishFunction: codeSearchFinishTool.asLLMFunction) else {
        throw SearchAgentError.noResultFromAgent
    }

    print("Result: \(finish.arguments)")
    guard let args = finish.decodeArguments(as: CodeSearchFinishFunctionArgs.self, stream: false) else {
        throw SearchAgentError.invalidResultFromAgent
    }
    return try args.assembleContext(ctx: ToolContext(activeDirectory: folderURL))
}

private enum SearchAgentError: Error {
    case noResultFromAgent
    case invalidResultFromAgent
}

private struct CodeSearchFinishFunctionArgs: FunctionArgs {
    var snippets: [Snippet]

    struct Snippet: Equatable, Codable {
        var path: String
        var ranges: [String] // e.g. 0-500
    }

    static var schema: [String : LLMFunction.JsonSchema] {
        [
            "snippets": .array(description: nil, itemType: .object(description: "List of the most relevant snippets to show to the engineer", properties: [
                "path": .string(description: nil),
                "ranges": .array(description: "List of ranges of the relevant snippets in this file, in format START-END, e.g. 0-500 or 1040-1080.", itemType: .string(description: nil))
            ], required: ["path", "ranges"]))
        ]
    }
}

extension CodeSearchFinishFunctionArgs {
    func assembleContext(ctx: ToolContext) throws -> String {
        // This "renders" the list of snippets into text in a format like this:
        /*
         [BEGIN SNIPPET {path} lines 200-210 of 400 total]
         20 def hello():
         21   print("Hi!")
         ... etc ...
         [END SNIPPET {lastpathcomponent}]
         ...Repeat for other snippets.
         Line numbers 0-indexed
         */
        var lines = [String]()
        for snippet in snippets {
            let url = try ctx.resolvePath(snippet.path)
            var encoding: String.Encoding = .utf8
            guard let contents = try? String(contentsOf: url, usedEncoding: &encoding) else {
                throw SearchAgentError.noResultFromAgent
            }
            
            let allLines = contents.components(separatedBy: .newlines)
            let totalLines = allLines.count
            
            for rangeStr in snippet.ranges {
                let rangeParts = rangeStr.components(separatedBy: "-")
                guard rangeParts.count == 2,
                      let start = Int(rangeParts[0]),
                      let end = Int(rangeParts[1]),
                      start >= 0, end < totalLines, start <= end else {
                    continue
                }

                let ofTotal = end - start + 1 == totalLines ? "(all)" : " of \(totalLines) total"
                lines.append("[BEGIN SNIPPET \(snippet.path) lines \(start)-\(end) \(ofTotal)]")
                
                for lineNum in start...end {
                    lines.append(String(format: "%5d %@", lineNum, allLines[lineNum]))
                }
                
                lines.append("[END SNIPPET \(url.lastPathComponent)]")
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }
}

class EphemeralAgent: AgentThreadStore {
    var model: ThreadModel

    init(model: ThreadModel) {
        self.model = model
    }

    func readThreadModel() async -> ThreadModel {
        model
    }
    
    func modifyThreadModel<ReturnVal>(_ callback: @escaping (inout ThreadModel) -> ReturnVal) async -> ReturnVal {
        callback(&model)
    }
}
