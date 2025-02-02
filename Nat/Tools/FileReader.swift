import Foundation
import ChatToys

struct FileReaderTool: Tool {
    var functions: [LLMFunction] {
        [Self.fn.asLLMFunction]
    }

    static let fn = TypedFunction<Args>(name: "read_file", description: "Shows you the contents of a file.", type: Args.self)

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

    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse? {
        if let args = Self.fn.checkMatch(call: call) {
            let path = args.path
            let offset = args.line_offset ?? 0
            do {
                let output = try await generateReadFileString(path: path, context: context, offset: offset)
                return call.response(items: [.fileSnippet(output)])
            }
            catch {
                return call.response(text: "[File Reader] Unable to read '\(args.path)': \(error)")
            }
        }
        return nil
    }
}

enum FileReaderError: Error {
    case fileNotFound(String)
}

extension LLMMessage.FunctionCall {
    func response(text: String) -> TaggedLLMMessage.FunctionResponse {
        TaggedLLMMessage.FunctionResponse(functionId: id, functionName: name, content: [.text(text)])
    }

    func response(items: [ContextItem]) -> TaggedLLMMessage.FunctionResponse {
        TaggedLLMMessage.FunctionResponse(functionId: id, functionName: name, content: items)
    }
}

private func generateReadFileString(path: String, context: ToolContext, offset: Int = 0, nLines: Int = 2000) async throws -> FileSnippet {
    let absoluteURL = try context.resolvePath(path)
    await context.log(.readFile(absoluteURL))
    var encoding: String.Encoding = .utf8
    guard let contents = try? String(contentsOf: absoluteURL, usedEncoding: &encoding) else {
        throw FileReaderError.fileNotFound(absoluteURL.path(percentEncoded: false))
    }
    
    let lines = contents.lines
    let totalLines = lines.count
    let startLine = min(offset, totalLines)
    let endLine = min(startLine + nLines, totalLines)

    return try FileSnippet(path: absoluteURL, projectRelativePath: path, lineStart: startLine, linesCount: endLine - startLine)
}
