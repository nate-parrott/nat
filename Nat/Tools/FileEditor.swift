import SwiftUI
import Foundation
import ChatToys

struct FileEditorTool: Tool {
    static let codeFence = "%%%"
    static let findReplaceDivider = "===WITH==="
    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String? {
        Constants.useLineNumbers ? sysPromptForLineNumberBasedEditing : sysPromptForReplaceBasedEditing
    }
    
    func handlePsuedoFunction(fromPlaintext response: String, context: ToolContext) async throws -> [ContextItem]? {
        let codeEdits = try CodeEdit.edits(fromString: response, toolContext: context)
        if codeEdits.isEmpty {
            return nil
        }
        print("[FileEditorTool] HANDLING PSUEDO FN:\n\(response)")
        let fileEdits = FileEdit.edits(fromCodeEdits: codeEdits)
        print("[FileEditorTool] parsed into file edits: \(fileEdits)")
        let editsDesc = fileEdits.map(\.description).joined(separator: ", ")

        var responseStrings = [String]()
        do {
            let confirmation: FileEditorReviewPanelResult = !context.confirmFileEdits ? .accept :  try await context.presentUI(title: "Accept Edits?") { (dismiss: @escaping (FileEditorReviewPanelResult) -> Void) in
                FileEditorReviewPanel(edits: fileEdits, finish: { result in
                    dismiss(result)
                }).asAny
            }
            
            switch confirmation {
            case .accept, .acceptWithComment:
                for edit in codeEdits { // TODO: use `fileEdits` instead
                    switch edit {
                    case .create: context.log(.createdFile((edit.url as NSURL).lastPathComponent ?? ""))
                    case .replace, .findReplace, .append: context.log(.editedFile((edit.url as NSURL).lastPathComponent ?? ""))
                    }
                }
                
                if case .acceptWithComment(let comment) = confirmation {
                    context.log(.info("Accepted with comment: \(comment)"))
                }
                responseStrings.append(try await apply(fileEdits: fileEdits, context: context))
                if case .acceptWithComment(let comment) = confirmation {
                    responseStrings.append("User approved this change, but left this comment:\n\(comment)")
                }
            case .reject:
                context.log(.rejectedEdit(editsDesc)) 
                responseStrings.append("User rejected your latest message's edits. They were rolled back Take a beat and let the user tell you more about what they wanted.")
                break
            case .requestChanged(let message):
                context.log(.requestedChanges(editsDesc))
                responseStrings.append("User requested changes to the edits in your last message. They were rolled back. Here is what they said:\n[BEGIN USER FEEDBACK]\n\(message)\n[END USER FEEDBACK]")
                break
            }
        } catch {
            print("FAILED TO APPLY EDITS: \(editsDesc)")
            responseStrings.append("Edits '\(editsDesc)' failed to apply due to error: \(error).")
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
                case .findReplace(path: let path, find: let find, replace: let replace):
                    if content == nil {
                        content = try String(contentsOf: path, encoding: .utf8)
                    }
                    content = try applyFindReplace(existing: content!, find: find, replace: replace)
                case .append(path: let path, content: let contentToAppend):
                    if content == nil {
                        content = try String(contentsOf: path, encoding: .utf8)
                    }
                    content! += "\n" + contentToAppend
                case .create(path: _, content: let newContent):
                    content = newContent
                case .replace(path: let path, lineRangeStart: let rangeStart, lineRangeLen: let rangeLen, lines: let newLines):
                    if content == nil {
                        content = try String(contentsOf: path, encoding: .utf8)
                    }
                    content = try applyReplacement(existing: content!, lineRangeStart: rangeStart, len: rangeLen, lines: newLines)
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
            summaries.append("Updated \(path.relativePath). New content:\n\(stringWithLineNumbers(content))\n")
        }
        return summaries.joined(separator: "\n\n")
    }
}

private func adjustEditIndices(edit: CodeEdit, previousEdits: [CodeEdit]) -> CodeEdit {
    guard case .replace(path: let url, lineRangeStart: var start, lineRangeLen: let len, lines: let newLines) = edit else {
        return edit
    }
    // Adjust indices based on previous edits to the same file
    for previousEdit in previousEdits {
        // Only consider edits to the same file
        guard previousEdit.url == url,
              case .replace(_, let prevEditStart, let prevEditOrigRangeLen, let prevEditLines) = previousEdit else {
            continue
        }
        
        let addedLineCount = prevEditLines.count
        let delta = addedLineCount - prevEditOrigRangeLen
//        let prevEditOrigRangeEnd = prevEditStart + prevEditOrigRangeLen

//        // If this edit starts after the previous edit, adjust both start and end
        if start >= prevEditStart {
            start += delta
        }

        // If this edit overlaps or comes before the previous edit, we don't adjust
        // as those edits should be handled separately or rejected
    }
    return .replace(path: url, lineRangeStart: start, lineRangeLen: len, lines: newLines)
}

func applyReplacement(existing: String, lineRangeStart: Int, len: Int, lines newLines: [String]) throws -> String {
    var lines = existing.lines

    // Ensure the range is valid
    guard lineRangeStart >= 0, lineRangeStart + len <= lines.count else {
        throw NSError(domain: "FileEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid line range \(lineRangeStart) len \(len)for file with \(lines.count) lines"])
    }

    lines.replaceSubrange(lineRangeStart..<(lineRangeStart + len), with: newLines)
    return lines.joined(separator: "\n")
}

func applyFindReplace(existing: String, find: [String], replace: [String]) throws -> String {
    var lines = existing.lines
    let matchingRanges = lines.ranges(of: find)
    if matchingRanges.count != 1 {
        throw NSError(domain: "FileEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected exactly 1 match for find, got \(matchingRanges.count)"])
    }
    let range = matchingRanges[0]
    lines.replaceSubrange(range, with: replace)
    return lines.joined(separator: "\n")
}

func stringWithLineNumbers(_ string: String, lineCharLimit: Int = 1000, indexStart: Int = 0) -> String {
    var lines = string.lines
    let fmt = NumberFormatter()
    fmt.locale = .init(identifier: "en_US")
    fmt.minimumIntegerDigits = lines.count > 900 ? 4 : (lines.count > 90 ? 3 : 2)
    lines = lines.enumerated().map { "\($0.offset + indexStart) \($0.element.truncateTailWithEllipsis(chars: lineCharLimit))" }
    return lines.joined(separator: "\n")
}

struct FileEdit {
    var path: URL
    var edits: [CodeEdit] // Line numbers are already adjusted, so can be applied immediately. Must be in order to be applied successfully.

    static func edits(fromCodeEdits codeEdits: [CodeEdit]) -> [FileEdit] {
        let byPath = codeEdits.grouped(\.url)
        return byPath.map { pair in
            let (path, edits) = pair
            let sortedEdits = edits.sorted(by: { ($0.startIndex ?? -1) < ($1.startIndex ?? -1) }).asArray
            var adjustedEdits = [CodeEdit]()
            for edit in sortedEdits {
                adjustedEdits.append(adjustEditIndices(edit: edit, previousEdits: adjustedEdits))
            }
            return .init(path: path, edits: adjustedEdits)
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

enum CodeEdit: Equatable {
    // line range end is INCLUSIVE and zero-indexed.
    case replace(path: URL, lineRangeStart: Int, lineRangeLen: Int, lines: [String])
    case create(path: URL, content: String)
    case append(path: URL, content: String)
    case findReplace(path: URL, find: [String], replace: [String])

    var startIndex: Int? {
        switch self {
        case .replace(_, let lineRangeStart, _, _):
            return lineRangeStart
        case .create:
            return 0
        case .findReplace: return nil
        case .append: return nil
        }
    }

    // TODO: Not great to show this method's output to the model bc it includes full paths
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
        case .findReplace(path: let path, find: let find, replace: let replace):
            return "Find/Replace in \(path.absoluteString)"
        case .append(path: let path, content: let content):
            return "Append \(content.lines.count) lines to \(path.absoluteString)"
        }
    }

    var url: URL {
        switch self {
        case .replace(path: let url, _, _, _): return url
        case .create(path: let url, _): return url
        case .findReplace(path: let url, find: _, replace: _): return url
        case .append(path: let url, content: _): return url
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
        let findReplacePattern = try NSRegularExpression(pattern: #"^>\s*FindReplace\s+([^:]+):(\d+)\s*$"#)
        let appendPattern = try NSRegularExpression(pattern: #"^>\s*Append\s+([^\s:]+)\s*$"#)

        for line in lines {
            if line == FileEditorTool.codeFence {
                if let cmd = currentCommand {
                    // End of code block - process the edit

                    let content = currentContent.joined(separator: "\n")

                    // Resolve the path relative to workspace
                    let resolvedPath = try toolContext.resolvePath(cmd.path)

                    if cmd.type == "FindReplace" {
                        if let (find, replace) = parseFindAndReplace(currentContent) {
                            edits.append(.findReplace(path: resolvedPath, find: find, replace: replace))
                        } else {
                            // Skip
                        }
                    } else if cmd.type == "Append" {
                        edits.append(.append(path: resolvedPath, content: content))
                    } else if cmd.type == "Create" {
                        edits.append(.create(path: resolvedPath, content: content))
                    } else if cmd.type == "Replace" || cmd.type == "Insert" {
                        // Parse the range
                        let rangeParts = cmd.range.split(separator: "-")
                        if rangeParts.isEmpty { continue }
                        
                        guard let start = Int(rangeParts[0]) else { continue }
                        
                        if cmd.type == "Insert" {
                            edits.append(.replace(path: resolvedPath, lineRangeStart: start, lineRangeLen: 0, lines: currentContent))
                        } else {
                            let end: Int
                            if rangeParts.count > 1 {
                                guard let parsedEnd = Int(rangeParts[1]) else { continue }
                                end = parsedEnd
                            } else {
                                end = start
                            }
                            let len = end - start + 1
                            edits.append(.replace(path: resolvedPath, lineRangeStart: start, lineRangeLen: len, lines: currentContent))
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

                if let match = findReplacePattern.firstMatch(in: line, range: range) {
                    let path = String(line[Range(match.range(at: 1), in: line)!])
                    currentCommand = (type: "FindReplace", path: path, range: "")
                } else if let match = createPattern.firstMatch(in: line, range: range) {
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
                } else if let match = appendPattern.firstMatch(in: line, range: range) {
                    let path = String(line[Range(match.range(at: 1), in: line)!])
                    currentCommand = (type: "Append", path: path, range: "")
                }
            }
        }
        
        return edits
    }
}

private func parseFindAndReplace(_ content: [String]) -> (find: [String], replace: [String])? {
    let split = content.split(separator: FileEditorTool.findReplaceDivider, omittingEmptySubsequences: false)
    if split.count == 2 {
        return (split[0].asArray, split[1].asArray)
    }
    return nil
}
