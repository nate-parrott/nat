import SwiftUI
import Foundation
import ChatToys

struct FileEditorTool: Tool {
    static let codeFence = "%%%"
    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String? {
        """
        # Editing files
        Use code fences to edit files. 
                
        To edit a file, open a code fence with \(Self.codeFence), then provide an editing command on the next line. Valid commands are:
        > Replace [path]:[line range start](-[line range end]?) // lines are 0-indexed, inclusive
        > Insert [path]:[line index] // Content will be inserted BEFORE line at this index!
        > Create [path]
        
        After the command, use subsequent lines to provide code to be added. Then close the code fence using another \(Self.codeFence).
        
        Do not use functions concurrently with code edits in the same response.
        You can use multiple code fences in a single response.
        Do not include comments explaining what you changed IN the code, since this code will be committed.
        Make sure to properly indent so that your new file has coherent indentation.
        When refactoring more than 60% of a file, replace the whole thing; otherwise try to make targeted edits or insertions.
        
        Your edits will be applied directly to the file, and your code may be linted or syntax-checked, so never say things like "...existing unchanged..." etc.
                
        When editing existing files, you MUST read the file first using read_file. After editing a file, I'll echo back the new version on disk post-edit.
        When editing, make sure your edits reference the MOST RECENT copy of the file in the thread.
        
        Line numbers are zero-indexed and inclusive. So replacing lines 0-2 would replace the first two lines of a file.
        
        # Editing examples
        
        This replaces lines 5-20 inclusive of file.swift:
        \(Self.codeFence)
        > Replace /path/file.swift:5-20
            new_val = input * 2
            return new_val
        \(Self.codeFence)
        
        To replace line 0:
        \(Self.codeFence)
        > Replace /file2.swift:0
        def main(arg):
        \(Self.codeFence)
        
        To insert at the top of a file:
        \(Self.codeFence)
        > Insert /file3.swift:0
        # New line
        # Another new line
        \(Self.codeFence)
        
        To replace the entire content of a 100-line file:
        \(Self.codeFence)
        > Replace /path/file4.swift:0-99
        ...new content...
        \(Self.codeFence)
        
        # Creating a new file
        
        Create a new file using similar syntax:
        \(Self.codeFence)
        > Create /file/hi_world.swift
        def main():
            print("hi")
        \(Self.codeFence)
        """
    }

    func handlePsuedoFunction(fromPlaintext response: String, context: ToolContext) async throws -> [ContextItem]? {
        let codeEdits = try CodeEdit.edits(fromString: response, toolContext: context)
        if codeEdits.isEmpty {
            return nil
        }
        let fileEdits = FileEdit.edits(fromCodeEdits: codeEdits)
        let editsDesc = fileEdits.map(\.description).joined(separator: ", ")

        var responseStrings = [String]()
        do {
            let confirmation = try await context.presentUI(title: "Accept Edits?") { (dismiss: @escaping (FileEditorReviewPanelResult) -> Void) in
                FileEditorReviewPanel(edits: fileEdits, finish: { result in
                    dismiss(result)
                }).asAny
            }
            switch confirmation {
            case .accept:
                for edit in codeEdits { // TODO: use `fileEdits` instead
                    switch edit {
                    case .create: context.log(.createdFile((edit.url as NSURL).lastPathComponent ?? ""))
                    case .replace: context.log(.editedFile((edit.url as NSURL).lastPathComponent ?? ""))
                    }
                }

                responseStrings.append(try await apply(fileEdits: fileEdits, context: context))
//                prevEdits.append(edit)
            case .reject:
                context.log(.rejectedEdit(editsDesc)) // TODO
                responseStrings.append("User rejected your latest message's edits. They were rolled back Take a beat and let the user tell you more about what they wanted.")
//                let remaining = edits[i+1..<edits.count]
//                if remaining.count > 0 {
//                    responseStrings.append("There were \(remaining.count) edits remaining, which will be cancelled. You may want to re-apply them after the user has approved the edits.")
//                }
                break
            case .requestChanged(let message):
//                context.log(.requestedChanges((edit.url as NSURL).lastPathComponent ?? ""))
                context.log(.requestedChanges(editsDesc))
                responseStrings.append("User requested changes to the edits in your last message. They were rolled back. Here is what they said:\n[BEGIN USER FEEDBACK]\n\(message)\n[END USER FEEDBACK]")
//                let remaining = edits[i+1..<edits.count]
//                if remaining.count > 0 {
//                    responseStrings.append("There were \(remaining.count) edits remaining, which will be cancelled. You may want to re-apply based on the user's feedback.")
//                }
                break
            }
        } catch {
            print("FAILED TO APPLY EDITS: \(editsDesc)")
            responseStrings.append("Edits '\(editsDesc)' failed to apply due to error: \(error).")
//            let remaining = edits[i+1..<edits.count]
//            if remaining.count > 0 {
//                responseStrings.append("There were \(remaining.count) edits remaining, which will be cancelled. You may want to re-apply when fixed.")
//            }
//            break
        }
        // TODO: return proper context items
        return [ContextItem.text(responseStrings.joined(separator: "\n\n"))]
    }

    private func apply(fileEdits: [FileEdit], context: ToolContext) async throws -> String {
        var allWrites = [(URL, String)]()
        var summaries = [String]()

        for fileEdit in fileEdits {
            var content: String?
            for codeEdit in fileEdit.edits {
                switch codeEdit {
                case .create(path: let path, content: let newContent):
                    content = newContent
                case .replace(path: let path, lineRangeStart: let rangeStart, lineRangeLen: let rangeLen, content: let newContent):
                    if content == nil {
                        content = try String(contentsOf: path, encoding: .utf8)
                    }
                    content = try applyReplacement(existing: content!, lineRangeStart: rangeStart, len: rangeLen, new: newContent)
                }
            }
            if let content {
                allWrites.append((fileEdit.path, content))
            }
        }
        for (path, content) in allWrites {
            if !FileManager.default.fileExists(atPath: path.deletingLastPathComponent().path(percentEncoded: false)) {
                try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
            }
            try content.write(to: path, atomically: true, encoding: .utf8)
            summaries.append("Updated \(path.path). New content:\n\(stringWithLineNumbers(content))\n")
        }
        return summaries.joined(separator: "\n\n")
    }
}

private func adjustEditIndices(edit: CodeEdit, previousEdits: [CodeEdit]) -> CodeEdit {
    guard case .replace(path: let url, lineRangeStart: var start, lineRangeLen: let len, content: let content) = edit else {
        return edit
    }
    // Adjust indices based on previous edits to the same file
    for previousEdit in previousEdits {
        // Only consider edits to the same file
        guard previousEdit.url == url,
              case .replace(_, let prevEditStart, let prevEditOrigRangeLen, let prevEditContent) = previousEdit else {
            continue
        }
        
        let addedLineCount = prevEditContent.lines.count
        let delta = addedLineCount - prevEditOrigRangeLen
//        let prevEditOrigRangeEnd = prevEditStart + prevEditOrigRangeLen

//        // If this edit starts after the previous edit, adjust both start and end
        if start >= prevEditStart {
            start += delta
        }

        // If this edit overlaps or comes before the previous edit, we don't adjust
        // as those edits should be handled separately or rejected
    }
    return .replace(path: url, lineRangeStart: start, lineRangeLen: len, content: content)
}

private func applyReplacement(existing: String, lineRangeStart: Int, len: Int, new: String) throws -> String {
    var lines = existing.lines

    // Ensure the range is valid
    guard lineRangeStart >= 0, lineRangeStart + len <= lines.count else {
        throw NSError(domain: "FileEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid line range \(lineRangeStart) len \(len)for file with \(lines.count) lines"])
    }

    lines.replaceSubrange(lineRangeStart..<(lineRangeStart + len), with: new.lines)
    return lines.joined(separator: "\n")
}

private func stringWithLineNumbers(_ string: String) -> String {
    var lines = string.lines
    lines = lines.enumerated().map { "\($0.offset): \($0.element)" }
    return lines.joined(separator: "\n")
}

struct FileEdit {
    var path: URL
    var edits: [CodeEdit] // Line numbers are already adjusted, so can be applied immediately. Must be in order to be applied successfully.

    static func edits(fromCodeEdits codeEdits: [CodeEdit]) -> [FileEdit] {
        let byPath = codeEdits.grouped(\.url)
        return byPath.map { pair in
            let (path, edits) = pair
            let sortedEdits = edits.sorted(by: { $0.startIndex < $1.startIndex }).asArray
            var adjustedEdits = [CodeEdit]()
            for edit in sortedEdits {
                adjustedEdits.append(adjustEditIndices(edit: edit, previousEdits: adjustedEdits))
            }
            return .init(path: path, edits: sortedEdits)
        }
    }

    var description: String {
        if edits.count == 0 { return "Empty edit" } // unexpected
        if edits.count == 1 {
            return edits[0].description
        }
        return "Multiple edits to \(edits[0].url.absoluteString)"
    }
}

enum CodeEdit {
    // line range end is INCLUSIVE and zero-indexed.
    case replace(path: URL, lineRangeStart: Int, lineRangeLen: Int, content: String)
    case create(path: URL, content: String)

    var startIndex: Int {
        switch self {
        case .replace(_, let lineRangeStart, _, _):
            return lineRangeStart
        case .create:
            return 0
        }
    }

    var description: String {
        // include name and line range
        switch self {
        case .replace(path: let path, lineRangeStart: let start, lineRangeLen: let len, _):
            if len == 0 {
                return "Insert \(path.absoluteString):\(start)"
            } else {
                return "Replace \(path.absoluteString):\(start)-\(start+len-1)" // subtract b/c a string range like 1:1 is equal to a len of zero
            }
        case .create(path: let path, _):
            return "Create \(path.absoluteString)"
        }
    }

    var url: URL {
        switch self {
        case .replace(path: let url, _, _, _): return url
        case .create(path: let url, _): return url
        }
    }

    static func edits(fromString string: String, toolContext: ToolContext) throws -> [CodeEdit] {
        var edits = [CodeEdit]()
        let lines = string.lines
        var currentContent = [String]()
        var currentCommand: (type: String, path: String, range: String)?
        
        // Command patterns
        let createPattern = try NSRegularExpression(pattern: #"^>\s*Create\s+([^\s:]+)\s*$"#)
        let replacePattern = try NSRegularExpression(pattern: #"^>\s*Replace\s+([^:]+):(\d+(?:-\d+)?)\s*$"#)
        let insertPattern = try NSRegularExpression(pattern: #"^>\s*Insert\s+([^:]+):(\d+)\s*$"#)
        
        for line in lines {
            if line == FileEditorTool.codeFence {
                if currentCommand != nil {
                    // End of code block - process the edit
                    if currentContent.isEmpty { continue }
                    
                    let content = currentContent.joined(separator: "\n")
                    let cmd = currentCommand!
                    
                    // Resolve the path relative to workspace
                    let resolvedPath = try toolContext.resolvePath(cmd.path)

                    if cmd.type == "Create" {
                        edits.append(.create(path: resolvedPath, content: content))
                    } else if cmd.type == "Replace" || cmd.type == "Insert" {
                        // Parse the range
                        let rangeParts = cmd.range.split(separator: "-")
                        if rangeParts.isEmpty { continue }
                        
                        guard let start = Int(rangeParts[0]) else { continue }
                        
                        if cmd.type == "Insert" {
                            edits.append(.replace(path: resolvedPath, lineRangeStart: start, lineRangeLen: 0, content: content))
                        } else {
                            let end: Int
                            if rangeParts.count > 1 {
                                guard let parsedEnd = Int(rangeParts[1]) else { continue }
                                end = parsedEnd
                            } else {
                                end = start
                            }
                            let len = end - start + 1
                            edits.append(.replace(path: resolvedPath, lineRangeStart: start, lineRangeLen: len, content: content))
                        }
                    }
                    
                    currentCommand = nil
                    currentContent = []
                } else {
                    // Start of code block - look for command
                    currentContent = []
                }
            } else if let cmd = currentCommand {
                // Inside a code block - accumulate content
                if line == "\\```" {
                    currentContent.append("```")
                } else {
                    currentContent.append(line)
                }
            } else if line.hasPrefix(">") {
                // Try each pattern in turn
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                
                if let match = createPattern.firstMatch(in: line, range: range) {
                    let path = String(line[Range(match.range(at: 1), in: line)!])
                    currentCommand = (type: "Create", path: path, range: "")
                } else if let match = replacePattern.firstMatch(in: line, range: range) {
                    let path = String(line[Range(match.range(at: 1), in: line)!])
                    let range = String(line[Range(match.range(at: 2), in: line)!])
                    currentCommand = (type: "Replace", path: path, range: range)
                } else if let match = insertPattern.firstMatch(in: line, range: range) {
                    let path = String(line[Range(match.range(at: 1), in: line)!])
                    let range = String(line[Range(match.range(at: 2), in: line)!])
                    currentCommand = (type: "Insert", path: path, range: range)
                }
            }
        }
        
        return edits
    }
}
