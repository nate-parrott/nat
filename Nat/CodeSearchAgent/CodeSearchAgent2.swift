import Foundation

//func codeSearch2() async throws -> [ContextItem] {
//    let initialPrompt = """
//    Act as an expert engineer pair-programming with another engineer in an unfamiliar codebase.
//    The other programmer will write the code, but they can only read parts of the codebase that you provide to them.
//    They have passed you a question or topic, relevant to a coding task they're doing.
//    It is your job to dive into the codebase and bring them snippets of code that they'll be able to use.
//    You will be evaluated on the comprehensiveness of the snippets you provide, and the signal to noise ratio; don't make them sift through too much junk.
//    
//    You will be given a prompt that they need you to answer, and a list of files. (This may not be all the files in the codebase).
//    Your job is to find relevant information in these files. You can do this into two ways:
//    - File reader:
//
//    [BEGIN FILE TREE]
//    \(fileTree)
//    [END FILE TREE]
//    
//    [[CONTEXT]]
//    
//    Next, the engineer will provide their search prompt:
//    """
//}

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

func grepToSnippets(pattern: String, folder: URL, linesAroundMatchToInclude spread: Int, limit: Int) async throws -> [FileSnippet] {
    var hits = try await grep(pattern: pattern, folder: folder)
    hits.shuffle()
    hits = hits.prefix(limit).asArray

    let snippetRanges = hits.map { hit in
        let start = max(0, hit.lineNumber - spread)
        return FileSnippetRange(path: hit.path, lineRangeStart: start, lineRangeEnd: start + spread * 2)
    }

    return FileSnippetRange.mergeOverlaps(ranges: snippetRanges)
        .map { snip in
            try! FileSnippet(path: snip.path, lineStart: snip.lineRangeStart, linesCount: snip.lineRangeEnd - snip.lineRangeStart)
        }
}

struct FileSnippetRange {
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

