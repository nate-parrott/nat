import SwiftUI
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

        var responseStrings = [String]()
        for (i, edit) in edits.enumerated() {
            do {
                let path = try context.resolvePath(edit.path)
                let adjustedEdit = adjustEditIndices(edit: edit, previousEdits: edits[0..<i].asArray)
                let confirmation = try await context.presentUI { (dismiss: @escaping (FileEditorReviewPanelResult) -> Void) in
                    FileEditorReviewPanel(path: path, edit: adjustedEdit, finish: { result in
                        dismiss(result)
                    }).asAny
                }
                switch confirmation {
                case .accept:
                    responseStrings.append(try await apply(edit: adjustedEdit, context: context))
                case .reject:
                    responseStrings.append("User rejected edit \(edit.description)")
                    let remaining = edits[i+1..<edits.count]
                    if remaining.count > 0 {
                        responseStrings.append("There were \(remaining.count) edits remaining, which will be cancelled. You may want to re-apply them after the user has approved the edits.")
                    }
                    break
                case .requestChanged(let message):
                    responseStrings.append("User requested changes to this edit: \(edit.description). Here is what they said:\n[BEGIN USER FEEDBACK]\n\(message)\n[END USER FEEDBACK]")
                    let remaining = edits[i+1..<edits.count]
                    if remaining.count > 0 {
                        responseStrings.append("There were \(remaining.count) edits remaining, which will be cancelled. You may want to re-apply based on the user's feedback.")
                    }
                    break
                }
            } catch {
                print("FAILED TO APPLY EDIT: \(edit)")
                responseStrings.append("Edit '\(edit)' failed to apply due to error: \(error).")
                let remaining = edits[i+1..<edits.count]
                if remaining.count > 0 {
                    responseStrings.append("There were \(remaining.count) edits remaining, which will be cancelled. You may want to re-apply when fixed.")
                }
                break
            }
        }
        return responseStrings.joined(separator: "\n\n")
    }

    private func apply(edit: CodeEdit, context: ToolContext) async throws -> String {
        switch edit {
        case .create(path: let path, content: let content):
            let url = try context.resolvePath(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
            return "Successfully created file at \(path)"
        case .replace(path: let path, lineRangeStart: let start, lineRangeEnd: let end, content: let content):
            let url = try context.resolvePath(path)
            let existingContent = try String(contentsOf: url, encoding: .utf8)
            let newContent = try applyReplacement(existing: existingContent, lineRangeStart: start, lineRangeEnd: end, new: content)
            
            // Write back to file
            try newContent.write(to: url, atomically: true, encoding: .utf8)
            
            return "Successfully modified file at \(path). New content:\n\n\(stringWithLineNumbers(newContent))"
        }
    }
}

private func adjustEditIndices(edit: CodeEdit, previousEdits: [CodeEdit]) -> CodeEdit {
    guard case .replace(path: let path, lineRangeStart: var start, lineRangeEnd: var end, content: let content) = edit else {
        return edit
    }
    // Adjust indices based on previous edits to the same file
    for previousEdit in previousEdits {
        // Only consider edits to the same file
        guard previousEdit.path == path,
              case .replace(_, let prevStart, let prevEnd, let prevContent) = previousEdit else {
            continue
        }
        
        let prevLines = prevContent.components(separatedBy: .newlines)
        let linesChanged = prevLines.count - (prevEnd - prevStart)
        
        // If this edit starts after the previous edit, adjust both start and end
        if start >= prevEnd {
            start += linesChanged
            end += linesChanged
        }
        // If this edit overlaps or comes before the previous edit, we don't adjust
        // as those edits should be handled separately or rejected
    }
    return .replace(path: path, lineRangeStart: start, lineRangeEnd: end, content: content)
}

private func applyReplacement(existing: String, lineRangeStart: Int, lineRangeEnd: Int, new: String) throws -> String {
    var lines = existing.components(separatedBy: .newlines)

    // Ensure the range is valid
    guard lineRangeStart >= 0, lineRangeEnd <= lines.count else {
        throw NSError(domain: "FileEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid line range \(lineRangeStart)-\(lineRangeEnd) for file with \(lines.count) lines"])
    }

    lines.replaceSubrange(lineRangeStart..<lineRangeEnd, with: new.components(separatedBy: .newlines))
    return lines.joined(separator: "\n")
}

private func stringWithLineNumbers(_ string: String) -> String {
    var lines = string.components(separatedBy: .newlines)
    lines = lines.enumerated().map { "\($0.offset): \($0.element)" }
    return lines.joined(separator: "\n")
}

enum CodeEdit {
    case replace(path: String, lineRangeStart: Int, lineRangeEnd: Int, content: String)
    case create(path: String, content: String)

    var description: String {
        // include name and line range
        switch self {
        case .replace(path: let path, lineRangeStart: let start, lineRangeEnd: let end, _):
            return "Replace \(path):\(start)-\(end)"
        case .create(path: let path, _):
            return "Create \(path)"
        }
    }

    var path: String {
        switch self {
        case .replace(path: let path, _, _, _): return path
        case .create(path: let path, _): return path
        }
    }
    
    

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

enum FileEditorReviewPanelResult: Equatable {
    case accept
    case reject
    case requestChanged(String)
}

struct FileEditorReviewPanel: View {
    var path: URL
    var edit: CodeEdit
    var finish: (FileEditorReviewPanelResult) -> Void

    @State private var diffText: Text?

    var body: some View {
        // TODO: Present diff
        NavigationStack {
            ScrollView {
                (diffText ?? Text("?"))
                .lineLimit(nil)
                .font(.system(.body, design: .monospaced))
                .padding()
            }
            .onAppear {
                diffText = try? edit.asDiff(filePath: path).asText(font: Font.system(size: 14, weight: .regular, design: .monospaced))
            }
            .navigationTitle("Review changes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { finish(.reject) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Accept") { finish(.accept) }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

extension CodeEdit {
    func asDiff(filePath: URL) throws -> Diff {
        switch self {
        case .replace(let path, let lineRangeStart, let lineRangeEnd, let content):
            let existingContent = try String(contentsOf: filePath, encoding: .utf8)
            let existingLines = existingContent.components(separatedBy: .newlines)
            let newLines = content.components(separatedBy: .newlines)
            
            var diff = Diff(lines: [])
            for (i, existingLine) in existingLines.enumerated() {
                if i == lineRangeStart {
                   for newLine in newLines {
                       diff.lines.append(.insert(newLine))
                   }
                } 
                if i >= lineRangeStart && i < lineRangeEnd {
                    diff.lines.append(.delete(existingLine))
                } else {
                    diff.lines.append(.same(existingLine))
                }
            }
            return diff
        case .create(let path, let content):
            let newLines = content.components(separatedBy: .newlines)
            var diff = Diff(lines: [])
            for newLine in newLines {
                diff.lines.append(.insert(newLine))
            }
            return diff
        }
    }
}
