import Foundation
import ChatToys

struct FileEditorTool: Tool {
    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String? {
        """
        # Editing files
        Use code fences to edit files. Each edit requires a path, a line range to delete, and new code to insert at that location. 
        You can replace single lines, larger segments, or the entire file.
        Do not use functions concurrently with code edits in the same response.
        Make sure to properly indent so that your replacement file as coherent indentation.
        
        Your edits will be applied directly to the file, and your code may be linted or syntax-checked, so never say things like "...existing unchanged..." etc.
        
        To insert content without deleting, choose a target line and replace it with the existing line PLUS new lines you want to insert.
        
        When editing existing files, you MUST read the file first using read_file. After editing a file, I'll echo back the new version on disk post-edit.
        
        # Editing examples
        
        This replaces lines 5-20 (up to but not including line 20) of file.swift:
        ```
        > Replace /path/file.swift:5-20
            new_val = input * 2
            return new_val
        ```
        
        To replace line 0:
        ```
        > Replace /file2.swift:0-1
        def main(arg):
        ```
        
        To insert at the top of a file:
        ```
        > Replace /file3.swift:0-0
        # New line
        # Another new line
        ```
        
        To replace the entire content of a 100-line file:
        ```
        > Replace /path/file4.swift:0-100
        ...new content...
        ```
        
        # Creating a new file
        
        Create a new file using similar syntax:
        ```
        > Create /file/hi_world.swift
        def main():
            print("hi")
        ```
        """
    }

    func handlePsuedoFunction(fromPlaintext response: String, context: ToolContext) async throws -> String? {
        let edits = CodeEdit.edits(fromString: response)
        if edits.isEmpty {
            return nil
        }
        return try await edits.asyncThrowingMap { edit in
            try await apply(edit: edit, context: context)
        }.joined(separator: "\n\n")
    }

    private func apply(edit: CodeEdit, context: ToolContext) async throws -> String {
        switch edit {
        case .create(path: let path, content: let content):
            let url = try context.resolvePath(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
            return "Created file at \(path)"
        case .replace(path: let path, lineRangeStart: let start, lineRangeEnd: let end, content: let content):
            let url = try context.resolvePath(path)
            let existingContent = try String(contentsOf: url, encoding: .utf8)
            var lines = existingContent.components(separatedBy: .newlines)
            
            // Ensure the range is valid
            guard start >= 0, end <= lines.count else {
                throw NSError(domain: "FileEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid line range \(start)-\(end) for file with \(lines.count) lines"])
            }
            
            // Replace the specified lines with new content
            let newLines = content.components(separatedBy: .newlines)
            lines.replaceSubrange(start..<end, with: newLines)
            
            // Write back to file
            let newContent = lines.joined(separator: "\n")
            try newContent.write(to: url, atomically: true, encoding: .utf8)
            
            return "Modified file at \(path). New content::\n\n\(stringWithLineNumbers(newContent))"
        }
    }
}

private func stringWithLineNumbers(_ string: String) -> String {
    var lines = string.components(separatedBy: .newlines)
    lines = lines.enumerated().map { "\($0.offset): \($0.element)" }
    return lines.joined(separator: "\n")
}

enum CodeEdit {
    case replace(path: String, lineRangeStart: Int, lineRangeEnd: Int, content: String)
    case create(path: String, content: String)

    static func edits(fromString string: String) -> [CodeEdit] {
        var edits = [CodeEdit]()
        var currentCommand: (type: String, path: String, start: Int?, end: Int?)? = nil
        var currentContent = [String]()
        
        let lines = string.components(separatedBy: .newlines)
        var inCodeBlock = false
        
        for line in lines {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End of block - process the command if we have one
                    if let command = currentCommand {
                        let content = currentContent.joined(separator: "\n")
                        if command.type == "Replace",
                           let start = command.start,
                           let end = command.end {
                            edits.append(.replace(path: command.path, 
                                               lineRangeStart: start, 
                                               lineRangeEnd: end, 
                                               content: content))
                        } else if command.type == "Create" {
                            edits.append(.create(path: command.path, content: content))
                        }
                    }
                    currentCommand = nil
                    currentContent = []
                }
                inCodeBlock = !inCodeBlock
                continue
            }
            
            guard inCodeBlock else { continue }
            
            if line.hasPrefix("> Replace ") {
                let parts = line.dropFirst("> Replace ".count)
                    .components(separatedBy: ":")
                if parts.count == 2 {
                    let path = parts[0]
                    let range = parts[1].components(separatedBy: "-")
                    if range.count == 2,
                       let start = Int(range[0]),
                       let end = Int(range[1]) {
                        currentCommand = ("Replace", path, start, end)
                    }
                }
            } else if line.hasPrefix("> Create ") {
                let path = String(line.dropFirst("> Create ".count))
                currentCommand = ("Create", path, nil, nil)
            } else if currentCommand != nil {
                currentContent.append(line)
            }
        }
        
        return edits
    }
}
