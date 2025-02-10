import AppKit
import Foundation
import ChatToys

struct InspectTool: Tool {
    var document: Document?
    
    private func listSortedFiles(in directory: URL) throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
        let filtered = contents.filter { !$0.lastPathComponent.hasPrefix(".") }
        
        return filtered.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return date1 < date2
        }
    }
    
    var functions: [LLMFunction] {
        [Self.fn.asLLMFunction]
    }
    
    static let fn = TypedFunction<Args>(name: "get_inspection_items", description: """
        Returns any new items (text files, images) that have been written to the inspection directory, then clears the directory.
        """, type: Args.self)
    
    struct Args: FunctionArgs {
        static var schema: [String: LLMFunction.JsonSchema] { [:] }
    }
    
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse? {
        if let _ = Self.fn.checkMatch(call: call) {
            guard let document = document else {
                return call.response(text: "No document available")
            }
            
            let inspectionDir = await document.inspectDir()
            
            let items = try listSortedFiles(in: inspectionDir)
            await context.log(.retrievedLogs(items.count))
            
            var contextItems: [ContextItem] = []
            contextItems.append(.text("Found \(items.count) items in: \(inspectionDir.path(percentEncoded: false))"))
            
            // Process each file
            for url in items {
                switch url.pathExtension.lowercased() {
                case "txt":
                    let content = try String(contentsOf: url).truncateMiddle(firstNLines: 30, lastNLines: 80)
                    contextItems.append(.text("Content of \(url.lastPathComponent):\n\(content)"))
                case "png", "jpg", "jpeg", "gif", "tiff":
                    if let img = try? NSImage(contentsOf: url)?.asLLMImage() {
                        contextItems.append(.text("Image \(url.lastPathComponent):\n"))
                        contextItems.append(.image(img))
                    }
                default:
                    contextItems.append(.text("Found file: \(url.lastPathComponent) but not a format I can read"))
                }
                // Delete the file
                try FileManager.default.removeItem(at: url)
            }
            
            return call.response(items: contextItems)
        }
        return nil
    }
    
    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String? {
        guard let document = document else {
            return nil
        }
        let inspectionDir = await document.inspectDir()
        return """
        # Inspector: debugging tests or viewing images
        You can't see print() statements from inside tests.
        Instead, to debug or inspect test output, you can write txt or image files to this directory: \(inspectionDir.path), then call get_inspection_items.
        You can also copy images here to view them.
        After writing something to this directory, call get_inspection_items to retrieve and clear the directory content.
        
        For example, you might run a test that writes a string to the inspect directory then call get_inspection_items to see what it said.
        """
    }
}

extension Document {
    func inspectDir() async -> URL {
        if let dir = await store.readAsync().inspectionDirectory {
            return dir
        }
        let newDir = await InspectDirAssigner.shared.assignDir()
        return await store.modifyAsync { state in
            // In case of a race condition where two threads are writing at same time, it may not still be nil; keep the earliest-set copy
            if state.inspectionDirectory == nil {
                state.inspectionDirectory = newDir
            }
            return state.inspectionDirectory!
        }
    }
}

private actor InspectDirAssigner {
    static let shared = InspectDirAssigner()
    
    var count = 0
    func assignDir() -> URL {
        let baseURL = FileManager.default.temporaryDirectory
        let fullPath = baseURL.appendingPathComponent("nat_inspect_\(count)", isDirectory: true)
        try! FileManager.default.createDirectory(at: fullPath, withIntermediateDirectories: true)
        count += 1
        return fullPath
    }
}
