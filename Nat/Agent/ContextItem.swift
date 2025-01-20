import SwiftUI

// Type representing a piece of context data in a thread
enum ContextItem: Equatable, Codable {
    case text(String)
    case fileSnippet(FileSnippet)
}

// Type representing a snippet of a file in the context
struct FileSnippet: Equatable, Codable {
    var path: URL
    var lineStart: Int // 0-indexed
    var linesCount: Int
    var fileTotalLen: Int
    var content: String

    init(path: URL, lineStart: Int, linesCount: Int) throws {
        // Written by Phil
        self.path = path
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
        output.append("%% BEGIN FILE SNIPPET [\(path.path)] Lines \(lineStart)-\(lineStart + fileTotalLen) of \(fileTotalLen) %%\n")

        let lines = content.lines

        // File contents with line numbers
//        let start = max(0, min(lineStart, lines.count - 1))
//        let end = min(lines.count, lineStart + linesCount)
        for (index, line) in lines[0..<linesCount].enumerated() {
            let lineNumber = lineStart + index
            output.append(String(format: "%5d %@", lineNumber, line.truncateTailWithEllipsis(chars: 400)))
        }

        // Footer
        let remainingLines = fileTotalLen - (lineStart + linesCount)
        let lastPathComponent = path.lastPathComponent
        output.append("\n%% END FILE SNIPPET [\(lastPathComponent)]; there are \(remainingLines) more lines available to read %%")
        return output.joined(separator: "\n")
    }
}
