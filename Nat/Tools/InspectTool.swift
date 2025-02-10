import Foundation
import ChatToys

struct InspectTool: Tool {
    var document: Document?
    
    var functions: [LLMFunction] {
        [Self.fn.asLLMFunction]
    }
    
    static let fn = TypedFunction<Args>(name: "get_inspection_items", description: """
        Returns any new items (text files, images) that have been written to the inspection directory, then clears the directory.
        Use this to retrieve output from tests or debug sessions that wrote to the inspection directory.
        The inspection directory path is provided in the function response if you need it.
        """, type: Args.self)
    
    struct Args: FunctionArgs {
        static var schema: [String: LLMFunction.JsonSchema] { [:] }
    }
    
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse? {
        if let _ = Self.fn.checkMatch(call: call) {
            guard let document = document else {
                return call.response(text: "No document available")
            }
            
            // Create inspection directory if needed
            let state = document.store.value
            let inspectionDir: URL
            if let existingDir = state.inspectionDirectory {
                inspectionDir = existingDir
            } else {
                // Create new temp directory
                let tempBaseURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("nat_inspection", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempBaseURL, withIntermediateDirectories: true)
                
                inspectionDir = tempBaseURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: inspectionDir, withIntermediateDirectories: true)
                
                // Save to document state
                var newState = state
                newState.inspectionDirectory = inspectionDir
                document.store.value = newState
            }
            
            // List all files in directory
            let items = try FileManager.default.contentsOfDirectory(at: inspectionDir, includingPropertiesForKeys: nil)
            
            var contextItems: [ContextItem] = []
            contextItems.append(.text("Inspection directory: \(inspectionDir.path)"))
            
            if items.isEmpty {
                contextItems.append(.text("No new items found in inspection directory."))
                return call.response(items: contextItems)
            }
            
            // Process each file
            for url in items {
                if url.pathExtension.lowercased() == "txt" {
                    let content = try String(contentsOf: url)
                    contextItems.append(.text("Content of \(url.lastPathComponent):\n\(content)"))
                } else {
                    // Assume it's an image or binary file
                    contextItems.append(.text("Found file: \(url.lastPathComponent)"))
                }
                
                // Delete the file
                try FileManager.default.removeItem(at: url)
            }
            
            return call.response(items: contextItems)
        }
        return nil
    }
    
    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String? {
        guard let document = document,
              let inspectionDir = document.store.value.inspectionDirectory else {
            return nil
        }
        return """
        To debug or inspect test output:
        Write files to this directory to inspect them in your next command: \(inspectionDir.path)
        Text files (.txt) will be shown directly, other files will be listed.
        Use get_inspection_items to retrieve and clear the directory.
        """
    }
}