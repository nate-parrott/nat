import Foundation
import ChatToys

/// Provides context about available documentation files to the agent
struct DocsTool: Tool {
    var document: Document?

    private var notes: String? {
        if let docsURL = document?.store.model.natDocsDir?.appendingPathComponent("notes.markdown", isDirectory: false) {
            return try? String(contentsOf: docsURL, encoding: .utf8).nilIfEmpty
        }
        return nil
    }

    private var filesInDocsFolder: [String] {
        if let docsDir = document?.store.model.natDocsDir {
            return (try? FileManager.default.contentsOfDirectory(atPath: docsDir.path(percentEncoded: false)).filter({ $0 != "notes.markdown" })) ?? []
        }
        return []
    }

    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String? {
        var lines = [String]()
        
        if let notes {
            lines.append("[USER'S NOTES ABOUT THIS REPO]\n\(notes)\n[END NOTES]")
        }
        
        let docFiles = filesInDocsFolder
        if docFiles.count > 0 {
            lines.append("These documentation files are available for you to read:")
            for doc in docFiles {
                lines.append("- nat_docs/\(doc)")
            }
        }
        
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}