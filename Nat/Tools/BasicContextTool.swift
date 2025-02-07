import Foundation
import ChatToys

struct BasicContextTool: Tool {
    var document: Document?
    var currentFilenameFromXcode: String?

    private var dateAndHourAsString: String {
        // Written by Phil
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy 'at' h a"
        return formatter.string(from: Date())
    }

    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String? {
        var lines = [String]()
        
        if context.document?.store.model.worktreeBranch != nil, context.document?.store.model.autorun ?? false {
            lines.append("""
            !!! You are in a self-contained worktree in Autopilot mode! Your job is to complete the user's task (or get as far as you can) and present them with code they can merge. Don't ask questions or ask for help unless COMPLETELY STUCK!
            When you think you are done, you should first:
            - try building or running relevant tests to confirm
            - run `git --no-pager diff` to see what you've written and find a way to improve it
            """)
        }
        
        if let currentFilenameFromXcode {
            lines.append("The user has this file open in Xcode. If they give you a vague instruction, they might want you to edit this file. [FILE]\(currentFilenameFromXcode)[/FILE]")
        }
        
        lines.append("Current date: \(dateAndHourAsString)")
        return lines.joined(separator: "\n")
    }
}