import Foundation

enum EditParser {
    enum Part {
        case textLines([String])
        case codeEdit(CodeEdit)
    }

    static func parse(string: String, toolContext: ToolContext) throws -> [Part] {
        var parts = [Part]()

        func appendLine(_ str: String) {
            if let last = parts.last, case .textLines(let lines) = last {
                parts[parts.count - 1] = .textLines(lines + [str])
            } else {
                parts.append(.textLines([str]))
            }
        }

//        var edits = [CodeEdit]()
        let lines = string.lines
        var currentContent = [String]()
        var currentCommand: (type: String, path: String, range: String)?

        // Command patterns
        let writePattern = try NSRegularExpression(pattern: #"^>\s*Write\s+([^\s:]+)\s*$"#)
        let replacePattern = try NSRegularExpression(pattern: #"^>\s*Replace\s+([^:]+):(\d+(?:-\d+)?)\s*$"#)
        let insertPattern = try NSRegularExpression(pattern: #"^>\s*Insert\s+([^:]+):(\d+)\s*$"#)
        let findReplacePattern = try NSRegularExpression(pattern: #"^>\s*FindReplace\s+([^\s:]+)\s*$"#)
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
                            parts.append(.codeEdit(.findReplace(path: resolvedPath, find: find, replace: replace)))
                        } else {
                            // Skip
                        }
                    } else if cmd.type == "Append" {
                        parts.append(.codeEdit(.append(path: resolvedPath, content: content)))
                    } else if cmd.type == "Write" {
                        parts.append(.codeEdit(.write(path: resolvedPath, content: content)))
                    } else if cmd.type == "Replace" || cmd.type == "Insert" {
                        // Parse the range
                        let rangeParts = cmd.range.split(separator: "-")
                        if rangeParts.isEmpty { continue }

                        guard let start = Int(rangeParts[0]) else { continue }

                        if cmd.type == "Insert" {
                            parts.append(.codeEdit(.replace(path: resolvedPath, lineRangeStart: start, lineRangeLen: 0, lines: currentContent)))
                        } else {
                            let end: Int
                            if rangeParts.count > 1 {
                                guard let parsedEnd = Int(rangeParts[1]) else { continue }
                                end = parsedEnd
                            } else {
                                end = start
                            }
                            let len = end - start + 1
                            parts.append(.codeEdit(.replace(path: resolvedPath, lineRangeStart: start, lineRangeLen: len, lines: currentContent)))
                        }
                    }

                    currentCommand = nil
                    currentContent = []
                } else {
                    // Start of code block - look for command
                    currentContent = []
                }
            } else if currentCommand != nil {
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
                } else if let match = writePattern.firstMatch(in: line, range: range) {
                    let path = String(line[Range(match.range(at: 1), in: line)!])
                    currentCommand = (type: "Write", path: path, range: "")
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
            } else {
                // Normal line
                appendLine(line)
            }
        }

        return parts
    }

    static func parseEditsOnly(from string: String, toolContext: ToolContext) throws -> [CodeEdit] {
        try parse(string: string, toolContext: toolContext).compactMap { x in
            if case .codeEdit(let codeEdit) = x {
                return codeEdit
            }
            return nil
        }
    }
}

private func parseFindAndReplace(_ content: [String]) -> (find: [String], replace: [String])? {
    let split = content.split(separator: FileEditorTool.findReplaceDivider, omittingEmptySubsequences: false)
    if split.count == 2 {
        return (split[0].asArray, split[1].asArray)
    }
    return nil
}
