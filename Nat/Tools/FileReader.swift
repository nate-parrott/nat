import Foundation
import ChatToys

struct FileReaderTool: Tool {
    var functions: [LLMFunction] {
        [fn.asLLMFunction]
    }

    let fn = TypedFunction<Args>(name: "read_file", description: "Shows you the contents of a file.", type: Args.self)

    struct Args: FunctionArgs {
        var path: String
        var line_offset: Int?

        static var schema: [String: LLMFunction.JsonSchema] {
            [
                "path": .string(description: "The path to the file"),
                "line_offset": .number(description: "Optional; use this to read more of as file if it was truncated")
            ]
        }
    }

    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> LLMMessage.FunctionResponse? {
        if let args = fn.checkMatch(call: call) {
            let path = args.path
            let offset = args.line_offset ?? 0
            let output = try generateReadFileString(path: path, context: context, offset: offset)
            return call.response(text: output)
        }
        return nil
    }

    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String? {
        nil
    }

    func inlineContextUpdates(previous: String, context: ToolContext) async throws -> String? {
        nil
    }
}

enum FileReaderError: Error {
    case fileNotFound(String)
}

extension LLMMessage.FunctionCall {
    func response(text: String) -> LLMMessage.FunctionResponse {
        .init(id: id, functionName: name, text: text)
    }
}

func generateReadFileString(path: String, context: ToolContext, offset: Int = 0, nLines: Int = 1000) throws -> String {
    let absoluteURL = try context.resolvePath(path)
    
    var encoding: String.Encoding = .utf8
    guard let contents = try? String(contentsOf: absoluteURL, usedEncoding: &encoding) else {
        throw FileReaderError.fileNotFound(absoluteURL.path(percentEncoded: false))
    }
    
    let lines = contents.components(separatedBy: .newlines)
    let totalLines = lines.count
    let startLine = min(offset, totalLines)
    let endLine = min(startLine + nLines, totalLines)
    
    var output = [String]()
    
    // Header
    output.append("%% BEGIN FILE SNIPPET [\(path)] Lines \(startLine)-\(endLine - 1) of \(totalLines) %%\n")
    
    // File contents with line numbers
    for (index, line) in lines[startLine..<endLine].enumerated() {
        let lineNumber = startLine + index
        output.append(String(format: "%5d %@", lineNumber, line))
    }
    
    // Footer
    let remainingLines = totalLines - endLine
    let lastPathComponent = absoluteURL.lastPathComponent
    output.append("\n%% END FILE SNIPPET [\(lastPathComponent)]; there are \(remainingLines) more lines available to read %%")
    
    return output.joined(separator: "\n")
}
