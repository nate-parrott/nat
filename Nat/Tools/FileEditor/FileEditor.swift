import SwiftUI
import Foundation
import ChatToys

struct FileEditorTool: Tool {
    static let codeFence = "%%%"
    static let findReplaceDivider = "===WITH==="
    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String? {
        Constants.useLineNumbers ? sysPromptForLineNumberBasedEditing : sysPromptForReplaceBasedEditing
    }
    
    func canHandlePsuedoFunction(fromPlaintext response: String) async throws -> Bool {
        return try EditParser.containsEditsOrMalformedEdits(string: response)
    }
    
    func handlePsuedoFunction(fromPlaintext response: String, context: ToolContext) async throws -> [ContextItem]? {
        var parseErrors = [String]()
        let codeEdits = try EditParser.parseEditsOnly(from: response, toolContext: context, parseErrors: &parseErrors)
        if parseErrors.count > 0 {
            await context.log(.toolError("Invalid edits"))
            return [.text("Your edits were not applied because of an error:\n\(parseErrors.joined(separator: ", "))")]
        }
        
        let validationErrors = codeEdits.compactMap { $0.validationError(context) }
        if validationErrors.count > 0 {
            await context.log(.toolError("Invalid edits"))
            return [.text("Your edits were not applied because of an error:\n\(parseErrors.joined(separator: ", "))")]
            
        }

        if codeEdits.isEmpty {
            return nil
        }
        let unfixedFileEdits = FileEdit.edits(fromCodeEdits: codeEdits)
        var fixedFileEdits = [FileEdit]()
        let editsDesc = unfixedFileEdits.map(\.description).joined(separator: ", ")

        // Dry-run applying changes before presenting to user
        // TODO: Concurrent
        for edit in unfixedFileEdits {
            do {
//                if edit.canBeAppliedUsingApplierModel {
//                    throw ApplyEditError.fakeError // For testing
//                }
                _ = try edit.getBeforeAfter()
                fixedFileEdits.append(edit)
            } catch {
                if edit.canBeAppliedUsingApplierModel {
                    await context.log(.usingEditCleanupModel(edit.path))
                    var errs = [String]()
                    let comments = try EditParser.parse(string: response, toolContext: context, parseErrors: &errs).compactMap(\.ifString).joined(separator: "\n\n[Code Edit]\n\n")
                    let newFullFileContent = try await edit.applyUsingLLM(comments: comments)
                    fixedFileEdits.append(.init(path: edit.path, edits: [.write(path: edit.path, content: newFullFileContent)]))
                } else {
                    await context.log(.toolError("Failed to apply edits"))
                    return [.text("Your edits were not applied because of an error:\n\(error)\nPlease try again or try a different approach, like rewriting a larger portion or the whole file.")]
                }
            }
        }

        var output = [ContextItem]()
        do {
            // Check syntax before showing confirmation dialog
            for fileEdit in fixedFileEdits {
                if let syntaxError = await fileEdit.checkSyntax() {
                    await context.log(.toolError("Syntax error in `\(fileEdit.path.lastPathComponent)`"))
                    let response: [ContextItem] = [.text("Your edits were not applied because the Swift code has syntax errors:\n\n\(syntaxError)\n\nPlease fix and try again. Consider rewriting the entire file rather than doing targeted edits.")]
                    return response + (try showLatestFileVersions(fileEdits: fixedFileEdits, context: context))
                }
            }
            
            let autorun = await context.autorun()
            let confirmation: FileEditorReviewPanelResult = autorun ? .accept :  try await context.presentUI(title: "Accept Edits?") { (dismiss: @escaping (FileEditorReviewPanelResult) -> Void) in
                FileEditorReviewPanel(edits: fixedFileEdits, finish: { result in
                    dismiss(result)
                }).asAny
            }

            let allEdits = fixedFileEdits.flatMap(\.edits)
            let log: UserVisibleLog.Edits = .init(paths: allEdits.map(\.url), accepted: confirmation.accepted, comment: confirmation.comment)
            await context.log(.edits(log))
            
            switch confirmation {
            case .accept, .acceptWithComment:
                output += try await apply(fileEdits: fixedFileEdits, context: context)
                if case .acceptWithComment(let comment) = confirmation {
                    output.append(.text("[User approved the change above, but left this comment:]\n\(comment)"))
                }
            case .reject:
                output.append(.text("User rejected your latest message's edits. They were rolled back. Take a beat and let the user tell you more about what they wanted."))
                output += try showLatestFileVersions(fileEdits: fixedFileEdits, context: context)
                break
            case .requestChanged(let message):
                output.append(.text("[User requested changes to the edits in your last message. They were rolled back. Here is what they said:\n\n\(message)"))
                output += try showLatestFileVersions(fileEdits: fixedFileEdits, context: context)
                break
            }
        } catch {
            print("FAILED TO APPLY EDITS: \(editsDesc)")
            output.append(.text("Edits '\(editsDesc)' failed to apply due to error: \(error)."))
        }
        // TODO: return proper context items
        return output
    }
    
    private func showLatestFileVersions(fileEdits: [FileEdit], context: ToolContext) throws -> [ContextItem] {
        var output = [ContextItem]()
        for fileEdit in fileEdits {
            if let content = try? String(contentsOf: fileEdit.path) {
                let projectRelativePath = context.activeDirectory.flatMap { fileEdit.path.asPathRelativeTo(base: $0) } ?? fileEdit.path.path()
                output.append(.text("\nLatest version of \(projectRelativePath):"))
                try output.append(.fileSnippet(FileSnippet(path: fileEdit.path, projectRelativePath: projectRelativePath, lineStart: 0, linesCount: content.lines.count)))
            }
        }
        return output
    }

    private func apply(fileEdits: [FileEdit], context: ToolContext) async throws -> [ContextItem] {
        var allWrites = [(URL, String)]()
        var output = [ContextItem]()

        for fileEdit in fileEdits {
            let content = try fileEdit.getBeforeAfter().1
            allWrites.append((fileEdit.path, content))
        }
        for (path, content) in allWrites {
            if !FileManager.default.fileExists(atPath: path.deletingLastPathComponent().path(percentEncoded: false)) {
                try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
            }

            let projectRelativePath: String = {
                if let dir = context.activeDirectory, let relative = path.asPathRelativeTo(base: dir) {
                    return relative
                }
                return path.path()
            }()

            try content.write(to: path, atomically: true, encoding: .utf8)
            output.append(.text("Updated \(projectRelativePath):"))
            try output.append(.fileSnippet(FileSnippet(path: path, projectRelativePath: projectRelativePath, lineStart: 0, linesCount: content.lines.count)))
        }
        return output
    }

    // MARK: apply_edits fn
    // HACK: The model tends to write edits and then call other functions, like running tests, rather than yielding to see if the edit is applied. Rather than let it do this, we provide a fake apply_edits function that a model can use.

    var functions: [LLMFunction] {
        [fn.asLLMFunction]
    }

    let fn = TypedFunction<Args>(name: "apply_edits", description: "Applies edits written using code fences in your response's main body, above this function call. NO ARGS FOR THIS FN DIRECTLY.", type: Args.self)

    struct Args: FunctionArgs {
        static var schema: [String : LLMFunction.JsonSchema] { [:] }
    }

    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse? {
        if fn.checkMatch(call: call) != nil {
            return call.response(text: "") // The real response will be sent by the psuedo-fn handler above
        }
        return nil
    }

}

extension FileEdit {
    var requiresReadFromDisk: Bool {
        for edit in edits {
            switch edit {
            case .replace: return true
            case .write: return false
            case .append: return true
            case .findReplace: return true
            }
        }
        return false
    }

    func getBeforeAfter() throws -> (String, String) {
        var before = ""
        // Always read from disk even when overwriting
//        if requiresReadFromDisk {
        if requiresReadFromDisk {
            before = try String(contentsOf: path, encoding: .utf8)
        } else {
            before = (try? String(contentsOf: path, encoding: .utf8)) ?? ""
        }
//        }
        let after = try applyToExisting(content: before)
        return (before, after)
    }

    func applyToExisting(content: String?) throws -> String {
        var content = content ?? ""
        for codeEdit in edits {
            switch codeEdit {
            case .findReplace(path: _, find: let find, replace: let replace):
                content = try applyFindReplace(existing: content, find: find, replace: replace)
            case .append(path: _, content: let contentToAppend):
                content += "\n" + contentToAppend
            case .write(path: _, content: let newContent):
                content = newContent
            case .replace(path: _, lineRangeStart: let rangeStart, lineRangeLen: let rangeLen, lines: let newLines):
                content = try applyReplacement(existing: content, lineRangeStart: rangeStart, len: rangeLen, lines: newLines)
            }
        }
        return content
    }
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

enum CodeEdit: Equatable, Codable {
    // line range end is INCLUSIVE and zero-indexed.
    case replace(path: URL, lineRangeStart: Int, lineRangeLen: Int, lines: [String])
    case write(path: URL, content: String)
    case append(path: URL, content: String)
    case findReplace(path: URL, find: [String], replace: [String])

    var startIndex: Int? {
        switch self {
        case .replace(_, let lineRangeStart, _, _):
            return lineRangeStart
        case .write:
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
        case .write(path: let path, _):
            return "Write \(path.absoluteString)"
        case .findReplace(path: let path, find: let find, replace: let replace):
            return "Find/Replace in \(path.absoluteString)"
        case .append(path: let path, content: let content):
            return "Append \(content.lines.count) lines to \(path.absoluteString)"
        }
    }

    var url: URL {
        switch self {
        case .replace(path: let url, _, _, _): return url
        case .write(path: let url, _): return url
        case .findReplace(path: let url, find: _, replace: _): return url
        case .append(path: let url, content: _): return url
        }
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
    if matchingRanges.count == 0 {
        throw ApplyEditError.noMatch("When applying FindReplace, you asked to replace this string, but it was not found VERBATIM in the latest copy of the file:\n\(find.joined(separator: "\n"))\n\nIf you're having trouble, consider using `Write` to replace the whole file.")
//        throw NSError(domain: "FileEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected exactly 1 match for find, got \(matchingRanges.count)"])
    } else if matchingRanges.count > 1 {
        throw ApplyEditError.moreThanOneMatch("When applying FindReplace, you asked to replace this string, but it was found more than once in the file:\n\(find.joined(separator: "\n"))\n\nThe `find` string should ONLY exist EXACTLY once verbatim in the file. If you're having trouble, consider using `Write` to replace the whole file.")
    }
    let range = matchingRanges[0]
    lines.replaceSubrange(range, with: replace)
    return lines.joined(separator: "\n")
}

private enum ApplyEditError: Error {
    case noMatch(String)
    case moreThanOneMatch(String)
    case fakeError
}

extension CodeEdit {
    func validationError(_ ctx: ToolContext) -> String? {
        if url.path().hasPrefix("/Users/") {
            return "You passed an absolute path to be edited, but you can only pass paths relative to the project root dir."
        }
        return nil
    }
}
