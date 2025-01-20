import Foundation
import ChatToys

struct GrepTool: Tool {
    var functions: [LLMFunction] {
        [fn.asLLMFunction]
    }
    
    let fn = TypedFunction<Args>(name: "grep", description: "Search for patterns in files using regex", type: Args.self)
    
    struct Args: FunctionArgs {
        var pattern: String
//        var linesOfContext: Int?
        
        static var schema: [String: LLMFunction.JsonSchema] {
            [
                "pattern": .string(description: "The regex pattern to search for. Will be passed to NSRegularExpression"),
            ]
        }
    }
    
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> LLMMessage.FunctionResponse? {
        guard let args = fn.checkMatch(call: call) else { return nil }
        
        guard let folderURL = context.activeDirectory else {
            return call.response(text: "Tell the user they need to choose a folder before you can search the codebase.")
        }
        
        context.log(.grepped(args.pattern))

        do {
            let hits = try await grepToSnippets(pattern: args.pattern, folder: folderURL, linesAroundMatchToInclude: 2, limit: 20)
            let str: String = "\(hits.count) hits:\n" + hits.map { hit in
                return hit.asString
            }.joined(separator: "\n\n")
            return call.response(text: str)
        } catch {
            return call.response(text: "Grep failed with error: \(error)")
        }
    }
}
