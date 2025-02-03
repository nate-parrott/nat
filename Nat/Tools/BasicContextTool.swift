import Foundation
import ChatToys

struct BasicContextTool: Tool {
    var document: Document?
    
    var currentFilenameFromXcode: String?

    var dateAndHourAsString: String {
        // Written by Phil
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy 'at' h a"
        return formatter.string(from: Date())
    }

    var notes: String? {
        if let docsURL = document?.store.model.natDocsDir?.appendingPathComponent("notes.markdown", isDirectory: false) {
            return try? String(contentsOf: docsURL, encoding: .utf8).nilIfEmpty
        }
        return nil
    }

    var filesInDocsFolder: [String] {
        if let docsDir = document?.store.model.natDocsDir {
            return (try? FileManager.default.contentsOfDirectory(atPath: docsDir.path(percentEncoded: false)).filter({ $0 != "notes.markdown" })) ?? []
        }
        return []
    }

    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String? {
        var lines = [String]()
        if context.document?.store.model.worktreeBranch != nil, context.document?.store.model.autorun ?? false {
            lines.append("!!! You are in a self-contained worktree in Autopilot mode! Your job is to complete the user's task (or get as far as you can) and present them with code they can merge. Don't ask questions or ask for help unless COMPLETELY STUCK! If you think you are done, try building or running relevant tests to confirm.")
        }
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
        if let currentFilenameFromXcode {
            lines.append("The user has this file open in Xcode. If they give you a vague instruction, they might want you to edit this file. [FILE]\(currentFilenameFromXcode)[/FILE]")
        }
        lines.append("Current date: \(dateAndHourAsString)")
        return lines.joined(separator: "\n")
    }
}
