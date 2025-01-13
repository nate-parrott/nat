import Foundation
import ChatToys

struct FileTreeTool: Tool {
    var functions: [LLMFunction] {
        [fn.asLLMFunction]
    }

    let fn = TypedFunction<Args>(name: "file_tree", description: "Use this to print the file tree. Use to figure out the current directory structure before creating a file.'", type: Args.self)

    struct Args: FunctionArgs {

        static var schema: [String: LLMFunction.JsonSchema] {
            [:]
        }
    }

    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> LLMMessage.FunctionResponse? {
        if let args = fn.checkMatch(call: call) {
            guard let folderURL = context.activeDirectory else {
                return call.response(text: "Tell the user they need to choose a folder before you can search the codebase.")
            }
            return call.response(text: FileTree.fullTree(url: folderURL))
        }
        return nil
    }
}
