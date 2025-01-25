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
            var resp = LLMMessage.FunctionResponse(id: functionId, functionName: functionName, text: "")
            var textItems = [String]()
            for item in content {
                let (str, img) = item.asStringOrImage
                if let str {
                    textItems.append(str)
                }
                if let img {
                    // TODO: support adding images
                    fatalError("Cannot add images as function response")
                }
            }
            resp.text = textItems.joined(separator: "\n\n")
            return resp
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

    func asPlainText(includeSystemMessages includeSys: Bool) -> String {
        var lines = [String]()
        for item in content {
            let (text, img) = item.asStringOrImage
            if let text {
                lines.append(text)
            }
            if img != nil {
                lines.append("[Image]")
            }
        }
        return lines.joined(separator: "\n\n")
    }
}

// Type representing a piece of context data in a thread
enum ContextItem: Equatable, Codable {
    case text(String)
    case fileSnippet(FileSnippet)
    case image(LLMMessage.Image)
    case systemInstruction(String)
    case textFile(filename: String, content: String)
    case url(URL)
    case largePaste(String)

    var asStringOrImage: (String?, LLMMessage.Image?) {
        switch self {
        case .text(let string):
            return (string, nil)
        case .fileSnippet(let fileSnippet):
            return (fileSnippet.asString, nil)
        case .image(let image):
            return (nil, image)
        case .systemInstruction(let str):
            return ("<s>\(str)</s>", nil)
        case .textFile(let filename, let content):
            return ("Attached file '\(filename)':\n\(content)", nil)
        case .url(let url):
            return ("URL: \(url.absoluteString)", nil)
        case .largePaste(let content):
            return ("Pasted content:\n\(content)", nil)
        }
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

    var asString: String {
        var output = [String]()
        output.append("%% BEGIN FILE SNIPPET [\(projectRelativePath)] Lines \(lineStart)-\(lineStart + linesCount - 1) of \(fileTotalLen) %%\n")

//        let lines = content.lines

//        for (index, line) in lines[0..<linesCount].enumerated() {
//            let lineNumber = lineStart + index
//            output.append(String(format: "%5d %@", lineNumber, line.truncateTailWithEllipsis(chars: 400)))
//        }

        output.append(stringWithLineNumbers(content, lineCharLimit: 400, indexStart: lineStart))

        // Footer
        let remainingLines = fileTotalLen - (lineStart + linesCount)
        let lastPathComponent = path.lastPathComponent
        output.append("\n%% END FILE SNIPPET [\(lastPathComponent)]; there are \(remainingLines) more lines available to read %%")
        return output.joined(separator: "\n")
    }
}
