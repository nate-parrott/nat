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
        let filename = (resolvedPath as NSURL).lastPathComponent ?? args.path
        
        // Show confirmation dialog
        let confirmed = await Alerts.showAppConfirmationDialog(
            title: "Confirm Delete",
            message: "Are you sure you want to delete '\(filename)'?",
            yesTitle: "Delete",
            noTitle: "Cancel"
        )
        
        guard confirmed else {
            return call.response(text: "File deletion cancelled")
        }
        
        await context.log(.deletedFile(resolvedPath))
        
        do {
            try FileManager.default.removeItem(at: resolvedPath)
            return call.response(text: "Successfully deleted file at \(args.path)")
        } catch {
            return call.response(text: "Failed to delete file: \(error)")
        }
    }
} 
