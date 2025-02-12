import Foundation
import ChatToys

struct FileTreeTool: Tool {
    var functions: [LLMFunction] {
        [fn.asLLMFunction]
    }

    let fn = TypedFunction<Args>(name: "file_tree", description: "Use this to print the file tree. Use to figure out the current directory structure before creating a file.'", type: Args.self)

    struct Args: FunctionArgs {
        let page: Int?
        
        static var schema: [String: LLMFunction.JsonSchema] {
            ["page": .number(description: "Optional page number (1-based) to view. Default 1.")]
        }
    }

    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse? {
        if let args: Args = fn.checkMatch(call: call) {
            await context.log(.listedFiles)
            guard let folderURL = context.activeDirectory else {
                return call.response(text: "Tell the user they need to choose a folder before you can search the codebase.")
            }
            
            let text = FileTree.fullTree(url: folderURL)
            return call.response(text: generatePaginatedText(text, page: args.page ?? 1))
        }
        return nil
    }
    
    private func generatePaginatedText(_ text: String, page: Int) -> String {
        let lines = text.components(separatedBy: .newlines)
        let linesPerPage = 700
        let totalPages = max(1, Int(ceil(Double(lines.count) / Double(linesPerPage))))
        let validPage = min(max(1, page), totalPages)
        
        let startIndex = (validPage - 1) * linesPerPage
        let endIndex = min(startIndex + linesPerPage, lines.count)
        
        var result = "Page \(validPage) of \(totalPages)\n\n"
        result += lines[startIndex..<endIndex].joined(separator: "\n")
        
        if validPage < totalPages {
            result += "\n\nThere are more files. Call file_tree again with page=\(validPage + 1) to see more."
        }
        
        return result
    }
}