import SwiftUI
import ChatToys

// An LLMessage where each piece of content is tagged with data about priority, etc
struct TaggedLLMMessage: Equatable, Codable {
    var role: LLMMessage.Role
    var content: [ContextItem]
    var functionCalls: [LLMMessage.FunctionCall]
    var functionResponses: [FunctionResponse]

    struct FunctionResponse: Equatable, Codable {
        var functionId: String?
        var functionName: String
        var content: [ContextItem]

        var asLLMResponse: LLMMessage.FunctionResponse {
            LLMMessage.FunctionResponse(
                id: functionId,
                functionName: functionName,
                text: content.map { $0.asPlainText() }.joined(separator: "\n\n")
            )
       }

        var asTaggedLLMResponse: TaggedLLMMessage.FunctionResponse {
            return .init(functionId: functionId, functionName: functionName, content: content)
        }
    }

    init(message: LLMMessage) {
        role = message.role
        content = [.text(message.content)] + message.images.map({ ContextItem.image($0) })
        functionCalls = message.functionCalls
        functionResponses = message.functionResponses.map({ resp in
            FunctionResponse(functionId: resp.id, functionName: resp.functionName, content: [.text(resp.text)])
        })
    }

    init(role: LLMMessage.Role, content: [ContextItem]) {
        self.role = role
        self.content = content
        self.functionCalls = []
        self.functionResponses = []
    }

    // Written by Phil
    init(functionResponses: [FunctionResponse]) {
        self.role = .function
        self.content = [] // functionResponses.flatMap { $0.content }
        self.functionCalls = []
        self.functionResponses = functionResponses
    }

    func asLLMMessage() -> LLMMessage {
        var msg = LLMMessage(role: role, content: "")
        msg.functionCalls = self.functionCalls
        msg.functionResponses = self.functionResponses.map(\.asLLMResponse)
        var contentLines = [String]()
        for content in content {
            let (str, img) = content.asStringOrImage
            if let str {
                contentLines.append(str)
            }
            if let img {
                msg.images.append(img)
            }
        }
        msg.content = contentLines.joined(separator: "\n\n")
        return msg
    }

    var asPlainText: String {
        asPlainText(includeSystemMessages: true)
    }

    // TODO: Remove `includeSystemMessages`??
    func asPlainText(includeSystemMessages includeSys: Bool) -> String {
        content.map({ $0.asPlainText() }).joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// Type representing a piece of context data in a thread
enum ContextItem: Equatable, Codable {
    case text(String)
    case fileSnippet(FileSnippet)
    case image(LLMMessage.Image)
    case systemInstruction(String)
    case textFile(filename: String, content: String)
    struct PageContent: Equatable, Codable {
        var text: String
        var loadComplete: Bool
    }
    
    case url(URL, pageContent: PageContent? = nil)
    case largePaste(String)
    case omission(String)

    var asStringOrImage: (String?, LLMMessage.Image?) {
        switch self {
        case .text(let string):
            return (string, nil)
        case .fileSnippet(let fileSnippet):
            return (fileSnippet.asString(withLineNumbers: Constants.useLineNumbers), nil)
        case .image(let image):
            return (nil, image)
        case .systemInstruction(let str):
            return ("<s>\(str)</s>", nil)
        case .textFile(let filename, let content):
            return ("Attached file '\(filename)':\n\(content)", nil)
        case .url(let url, pageContent: let content):
            var result = "URL: \(url.absoluteString)"
            if let content {
                result += "\n\n" + content.text
            }
            return (result, nil)
        case .largePaste(let content):
            return ("Pasted content:\n\(content)", nil)
        case .omission(let msg): return ("[\(msg)]", nil)
        }
    }

    func asPlainText() -> String {
        var lines = [String]()
        let (text, img) = asStringOrImage
        if let text {
            lines.append(text)
        }
        if img != nil {
            lines.append("[Image]")
        }
        return lines.joined(separator: "\n\n")
    }

    var summary: (icon: String, name: String) {
        switch self {
        case .text:
            return ("text.bubble", "Text")
        case .fileSnippet(let snip):
            return ("doc.text", snip.path.lastPathComponent)
        case .image:
            return ("photo", "Image")
        case .systemInstruction:
            return ("gearshape", "System Instruction")
        case .textFile(filename: let name, content: _):
            return ("doc", name)
        case .url(let url, pageContent: let content):
            let str = "\(url.host() ?? ""): \(content?.text.count ?? 0) chars"
            return ("link", str)
        case .largePaste:
            return ("doc.on.clipboard", "Paste")
        case .omission:
            return ("ellipsis", "Omission")
        }
    }
    
    var loading: Bool {
        if case .url(_, let pageContent) = self, let pageContent {
            return !pageContent.loadComplete
        }
        return false
    }
}

// Type representing a snippet of a file in the context
struct FileSnippet: Equatable, Codable {
    var path: URL
    var projectRelativePath: String
    var lineStart: Int // 0-indexed
    var linesCount: Int
    var fileTotalLen: Int
    var content: String

    init(path: URL, projectRelativePath: String, lineStart: Int, linesCount: Int) throws {
        // Written by Phil
        self.path = path
        self.projectRelativePath = projectRelativePath
        self.lineStart = lineStart

        var enc: String.Encoding = .utf8
        let fileContent = try String(contentsOf: path, usedEncoding: &enc)
        let allLines = fileContent.lines

//        guard lineStart >= 0, linesCount > 0, lineStart + linesCount <= allLines.count else {
//            throw NSError(domain: "FileSnippet", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid range of lines"])
//        }

        let end = min(allLines.count, lineStart + linesCount)
        let start = min(lineStart, max(0, allLines.count - 1))

        let selectedLines = allLines[start..<end]
        self.linesCount = min(linesCount, selectedLines.count)
        self.content = selectedLines.joined(separator: "\n")
        self.fileTotalLen = allLines.count
    }

    func asString(withLineNumbers: Bool) -> String {
        var output = [String]()
        output.append("%% BEGIN FILE SNIPPET [\(projectRelativePath)] Lines \(lineStart)-\(lineStart + linesCount - 1) of \(fileTotalLen) %%\n")

        if withLineNumbers {
            output.append(stringWithLineNumbers(content, lineCharLimit: 400, indexStart: lineStart))
        } else {
            output += content.lines.map({ $0.truncateTailWithEllipsis(chars: 400) })
        }

        // Footer
        let remainingLines = fileTotalLen - (lineStart + linesCount)
        let lastPathComponent = path.lastPathComponent
        output.append("\n%% END FILE SNIPPET [\(lastPathComponent)]; there are \(remainingLines) more lines available to read %%")
        return output.joined(separator: "\n")
    }
}

extension Array where Element == TaggedLLMMessage {
    func byDroppingRedundantContext() -> [TaggedLLMMessage] {
        var result = self

        var pathsToOmit = Set<URL>()

        // Run this method over all context items in reverse order, so we keep the LAST full copy of each file snippet
        func processContextItem(_ item: ContextItem) -> ContextItem {
            if item.isSnippetWithAnyOfThesePaths(pathsToOmit), case .fileSnippet(let snippet) = item {
                return .omission("[Old copy of \(snippet.projectRelativePath) omitted here]")
            }
            if let path = item.isFullFileSnippet_returningPath() {
                pathsToOmit.insert(path)
            }
            return item

        }

        for i in result.indices.reversed() {
            result[i].content = result[i].content.map(processContextItem(_:))
            for j in result[i].functionResponses.indices {
                result[i].functionResponses[j].content = result[i].functionResponses[j].content.map(processContextItem(_:))
            }
        }

        return result
    }
}

private extension ContextItem {
    // HACK: Handle files who we've read
    func isSnippetWithPath(_ url: URL) -> Bool {
        if case .fileSnippet(let fileSnippet) = self {
            return fileSnippet.path == url
        }
        return false
    }

    func isSnippetWithAnyOfThesePaths(_ paths: Set<URL>) -> Bool {
        if case .fileSnippet(let fileSnippet) = self {
            return paths.contains(fileSnippet.path)
        }
        return false
    }

    func isFullFileSnippet_returningPath() -> URL? {
        if case .fileSnippet(let fileSnippet) = self {
            if fileSnippet.fileTotalLen == fileSnippet.linesCount {
                return fileSnippet.path
            }
        }
        return nil
    }
}
