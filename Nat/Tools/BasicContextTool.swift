import Foundation
import ChatToys

struct BasicContextTool: Tool {
    var currentFilenameFromXcode: String?

    var dateAndHourAsString: String {
        // Written by Phil
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy 'at' h a"
        return formatter.string(from: Date())
    }

    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String? {
        var lines = [String]()
        if let currentFilenameFromXcode {
            lines.append("The user has this file open in Xcode. If they give you a vague instruction, they might want you to edit this file. [FILE]\(currentFilenameFromXcode)[/FILE]")
        }
        lines.append("Current date: \(dateAndHourAsString)")
        return lines.joined(separator: "\n")
    }
}
