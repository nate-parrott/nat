import Foundation

func grep(pattern: String, folder: URL) async throws -> [GrepHit] {
    let regex = try NSRegularExpression(pattern: pattern)
    let allFileURLs = try FileTree.allFileURLs(folder: folder)
    let res: [[GrepHit]] = await allFileURLs.concurrentMap { url -> [GrepHit] in
        if !isTextFile(fileExtension: url.pathExtension) {
            return []
        }
        guard let content = try? String(fromURL: url) else {
            return [GrepHit]()
        }
        return content.lines.enumerated().compactMap { (pair) in
            let (i, str) = pair
            let nsstr = str as NSString
            if regex.firstMatch(in: str, options: [], range: NSRange(location: 0, length: nsstr.length)) != nil {
                return GrepHit(path: url, lineNumber: i)
            }
            return nil
        }
    }
    return res.flatMap({ $0 })
}

func grepToSnippetRanges(pattern: String, folder: URL, linesAroundMatchToInclude spread: Int, limit: Int) async throws -> [FileSnippetRange] {
    var hits = try await grep(pattern: pattern, folder: folder)
    hits.shuffle()
    hits = hits.prefix(limit).asArray

    let snippetRanges = hits.map { hit in
        let start = max(0, hit.lineNumber - spread)
        return FileSnippetRange(path: hit.path, lineRangeStart: start, lineRangeEnd: start + spread * 2)
    }

    return FileSnippetRange.mergeOverlaps(ranges: snippetRanges)
}

func grepToSnippets(pattern: String, folder: URL, linesAroundMatchToInclude spread: Int, limit: Int) async throws -> [FileSnippet] {
    try await grepToSnippetRanges(pattern: pattern, folder: folder, linesAroundMatchToInclude: spread, limit: limit).compactMap { range -> FileSnippet? in
        guard let relative = range.path.asPathRelativeTo(base: folder) else {
            return nil
        }
        return try! FileSnippet(path: range.path, projectRelativePath: relative, lineStart: range.lineRangeStart, linesCount: range.lineRangeEnd - range.lineRangeStart)
    }
}

struct FileSnippetRange: Equatable {
    var path: URL
    var lineRangeStart: Int
    var lineRangeEnd: Int

    static func mergeOverlaps(ranges: [FileSnippetRange]) -> [FileSnippetRange] {
        // TODO: implement
        return ranges
    }
}

struct GrepHit {
    var path: URL
    var lineNumber: Int // zero-indexed
}

