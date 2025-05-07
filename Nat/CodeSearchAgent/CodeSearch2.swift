import ChatToys
import Foundation

struct CodeSearchResult {
    var snippets: [FileSnippet]
    var stats: SearchStats
}

func codeSearch2(queries: [String], folder: URL, context: ToolContext, effort: CodeSearchEffort = .one) async throws -> CodeSearchResult {
    if queries.isEmpty {
        return CodeSearchResult(snippets: [], stats: SearchStats(timeElapsed: 0, filesRead: 0, agentsSpawned: 0))
    }
    
    let startTime = Date()
    var filesRead = 0
    var agentsSpawned = 0
    
    let chunks: [String] = FileTree.chunksOfEntriesFromDir(url: folder, entriesInChunk: 200)
    let results: [(Int, FileSnippet)] = try await chunks.concurrentMapThrowing {
        agentsSpawned += 1
        let (items, readCount) = try await _codeSearch2(queries: queries, folder: folder, context: context, chunkOfFileTree: $0, effort: effort)
        filesRead += readCount
        return items
    }.flatMap({ $0 })
    
    let topResults: [FileSnippet] = results
        .sorted(by: { $0.0 > $1.0 })
        .prefix(effort.maxSnippetsToReturn).map({ $0.1 })
        .map({ $0.truncatingContent(maxLen: 6000) })
        .asArray
        
    let stats = SearchStats(
        timeElapsed: Date().timeIntervalSince(startTime),
        filesRead: filesRead,
        agentsSpawned: agentsSpawned
    )
    
    return CodeSearchResult(snippets: topResults, stats: stats)
}

enum CodeSearchError: Error {
    case notRelativeToProjectDir
}

// Returns scored snippets
private func _codeSearch2(queries: [String], folder: URL, context: ToolContext, chunkOfFileTree: String, effort: CodeSearchEffort) async throws -> ([(Int, FileSnippet)], Int) {
    print(chunkOfFileTree)
    let queriesList = queries.joined(separator: "\n- ")
    let prompt = """
    Act as an expert engineer pair-programming with another engineer in an unfamiliar codebase.
    The other programmer will write the code, but they can only read parts of the codebase that you provide to them.
    They have passed you a question or topic, relevant to a coding task they're doing.
    It is your job to dive into the codebase and bring them snippets of code that they'll be able to use.
    You will be evaluated on the comprehensiveness of the snippets you provide, and the signal to noise ratio; don't make them sift through too much junk.
    
    You will be given a prompt that they need you to answer, and a list of files. (This may not be all the files in the codebase).
    First, you'll choose a set of likely-relevant files to view.
    Then, you'll identify which snippets (if any) of these files seem most promising.
    These will be provided to the engineer.

    [BEGIN FILE TREE]
    \(chunkOfFileTree)
    [END FILE TREE]
        
    [[CONTEXT]]
    
    Next, here are ALL the individual search queries the engineer is interested in:
    \(queriesList)
    
    Respond using JSON, in this exact format:
    ```
    {
        paths: [String] // The paths of the most relevant files you want to read. Include at least 1, up to 10, relevant files, sorted most relevant first.
    }
    ```
    
    Pass ONLY valid paths proper paths from the file tree.
    (Paths may contain spaces.)
    """

    struct Response1: Codable {
        var paths: [String]
    }

    var messages = [
        LLMMessage(role: .user, content: prompt),
    ]

    let llm = try LLMs.quickModel()
    let relevantItems = try await llm.completeJSONObject(prompt: messages, type: Response1.self)
    var snippetRanges: [FileSnippetRange] = []
    for file in relevantItems.paths.prefix(effort.filesToReadPerChunk) {
        let resolvedPath = try context.resolvePath(file)
//        print(resolvedPath.path)
        snippetRanges.append(.init(path: resolvedPath, lineRangeStart: 0, lineRangeEnd: effort.linesToRead))
        await context.log(.readFile(resolvedPath))
    }
    if snippetRanges.count == 0 {
        return ([], 0)
    }
    // STEP 2:
    messages.removeAll()
    messages.append(.init(role: .system, content: """
    Act as an expert engineer pair-programming with another engineer in an unfamiliar codebase.
    The other programmer will write the code, but they can only read parts of the codebase that you provide to them.
    They have passed you a question or topic, relevant to a coding task they're doing.
    It is your job to dive into the codebase and bring them snippets of code that answer their question.
    You will be evaluated on whether you return ONLY snippets that answer the user question.
    
    You will be given a prompt that they need you to answer, and a list of file snippets.
    Your job is to identify identify which snippets (if any) of these files seem most promising.
    Make sure to read ALL questions and provide snippets that answer ALL of them, IF relevant snippets exist in your input.
    These will be provided to the engineer.
    
    [BEGIN FILE SNIPPETS]
    """))

    let snippets: String = FileSnippetRange.mergeOverlaps(ranges: snippetRanges)
        .compactMap({
            do {
                guard let relative = $0.path.asPathRelativeTo(base: folder) else {
                    throw CodeSearchError.notRelativeToProjectDir
                }
                return try FileSnippet(
                    content: context.readFileContentIncludingStaged($0.path),
                    path: $0.path,
                    projectRelativePath: relative,
                    lineStart: $0.lineRangeStart,
                    linesCount: $0.lineRangeEnd)
            } catch {
                print("[CodeSearch2] Error: \(error)")
                return nil
            }
        })
        .map { $0.asString(withLineNumbers: true) }
        .joined(separator: "\n\n")
    messages.append(.init(role: .user, content: snippets))
    messages.append(.init(role: .user, content: """
    [END FILE SNIPPETS]
    Keep in mind I've only shown you the first 1000 lines of each file.
    
    Now, your job is to think back to the engineer's original question, and extract
    the most relevant parts of this file. Extract ALL parts of the file that would be necessary
    to answer the question and make a related code edit, but ONLY if relevant to one of these queries. (Be precise!)
    ONLY include snippets of files you have READ and can see the content above.
    
    ONLY include useful, valuable data; it's ok to return nothing if nothing is relevant to the question.
    Here's what the user is looking for:
    \(queriesList)
    
    Choose file snippets by responding in this exact JSON format:
    ```
    interface Response {
        snippets: { 
            path: string, 
            ranges: string[],
            score: number // 0-100 how relevant is this file?
        }[] 
        // `ranges` is an array of line ranges in format "START-END", like 0-15
    }
    ```
    """))

    struct Response2: Codable {
        struct Snippet: Codable {
            var path: String
            var ranges: [String]
            var score: Int
        }
        var snippets: [Snippet]
    }

    // Written by Phil
    let finalSnippets = try await llm.completeJSONObject(prompt: messages, type: Response2.self).snippets

    var items = [(Int, FileSnippet)]()
    for snippet in finalSnippets {
        for range in snippet.ranges {
            let path = try context.resolvePath(snippet.path)
            if let (start, end) = parseRange(range) {
                do {
                    let content = try context.readFileContentIncludingStaged(path)
                    try items.append((
                        snippet.score,
                        FileSnippet(content: content, path: path, projectRelativePath: snippet.path, lineStart: start, linesCount: end - start + 1)
                    ))
                } catch {
                    print("[_CodeSearch2] ⚠️ Error creating final snippet ranges: \(error)")
                    await context.log(.toolWarning("Failed to read file \(path.path(percentEncoded: false))"))
                }
            }
        }
    }
    return (items, snippetRanges.count)
}

private func parseRange(_ str: String) -> (Int, Int)? {
    // Written by Phil
    let parts = str.split(separator: "-").compactMap({ Int($0) })
    if parts.count == 2 {
        return (parts[0], parts[1])
    }
    return nil
}
