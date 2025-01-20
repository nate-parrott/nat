import Foundation
import ChatToys

struct DeleteFileTool: Tool {    
    var functions: [LLMFunction] {
        [fn.asLLMFunction]
    }
    
    let fn = TypedFunction<Args>(name: "delete_file", description: "Deletes a file at the specified path", type: Args.self)
    
    struct Args: FunctionArgs {
        var path: String
        
        static var schema: [String: LLMFunction.JsonSchema] {
            [
                "path": .string(description: "The path to the file to delete")
            ]
        }
    }
    
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse? {
        guard let args = fn.checkMatch(call: call) else { return nil }
        
        let resolvedPath = try context.resolvePath(args.path)
        context.log(.deletedFile((resolvedPath as NSURL).lastPathComponent ?? ""))
        
        do {
            try FileManager.default.removeItem(at: resolvedPath)
            return call.response(text: "Successfully deleted file at \(args.path)")
        } catch {
            return call.response(text: "Failed to delete file: \(error)")
        }
    }
} 
