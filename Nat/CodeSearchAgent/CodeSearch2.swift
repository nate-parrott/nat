import ChatToys
import Foundation

func codeSearch2(queries: [String], folder: URL, context: ToolContext) async throws -> [FileSnippet] {
    let chunks: [String] = FileTree.chunksOfEntriesFromDir(url: folder, entriesInChunk: 200)
    let results: [(Int, FileSnippet)] = try await chunks.concurrentMapThrowing {
        try await _codeSearch2(queries: queries, folder: folder, context: context, chunkOfFileTree: $0)
    }.flatMap({ $0 })
    let topResults: [FileSnippet] = results
        .sorted(by: { $0.0 > $1.0 })
        .prefix(Constants.codeSearchToolMaxSnippetsToReturn).map({ $0.1 })
        .asArray
    return topResults
}

// Returns scored snippets
private func _codeSearch2(queries: [String], folder: URL, context: ToolContext, chunkOfFileTree: String) async throws -> [(Int, FileSnippet)] {
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
        paths: [String] // The paths of the most relevant files you want to read. Can be empty if absolutely nothing seems relevant to any of the queries. Most relevant first.
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
    for file in relevantItems.paths.prefix(Constants.codeSearchFilesToReadPerChunk) {
        let resolvedPath = try context.resolvePath(file)
//        print(resolvedPath.path)
        snippetRanges.append(.init(path: resolvedPath, lineRangeStart: 0, lineRangeEnd: Constants.codeSearchLinesToRead))
        context.log(.readFile(resolvedPath.lastPathComponent))
    }
//    for grep in relevantItems.greps.prefix(3) {
//        snippetRanges += try await grepToSnippetRanges(pattern: grep, folder: folder, linesAroundMatchToInclude: 2, limit: 10)
//        context.log(.grepped(grep))
//    }
    if snippetRanges.count == 0 {
        return []
    }
    // STEP 2:
    messages.removeAll()
    messages.append(.init(role: .system, content: """
    Act as an expert engineer pair-programming with another engineer in an unfamiliar codebase.
    The other programmer will write the code, but they can only read parts of the codebase that you provide to them.
    They have passed you a question or topic, relevant to a coding task they're doing.
    It is your job to dive into the codebase and bring them snippets of code that they'll be able to use.
    You will be evaluated on the comprehensiveness of the snippets you provide, and the signal to noise ratio; don't make them sift through too much junk.
    
    You will be given a prompt that they need you to answer, and a list of file snippets.
    Your job is to identify identify which snippets (if any) of these files seem most promising.
    These will be provided to the engineer.
    """))

    let snippets: String = FileSnippetRange.mergeOverlaps(ranges: snippetRanges)
        .compactMap({
            do {
                return try FileSnippet(path: $0.path, lineStart: $0.lineRangeStart, linesCount: $0.lineRangeEnd)
            } catch {
                print("[CodeSearch2] Error: \(error)")
                return nil
            }
        })
        .map(\.asString)
        .joined(separator: "\n\n")
    messages.append(.init(role: .user, content: snippets))
    messages.append(.init(role: .user, content: """
    OK, great. There's some data you requested. Keep in mind I've only shown you the first 1000 lines of each file.
    
    Now, your job is to think back to the engineer's original question, and extract
    the most relevant parts of this file. Extract ALL parts of the file that would be necessary
    to answer the question and make a related code edit.
    ONLY include snippets of files you have READ and can see the content above.
    
    ONLY include useful, valuable data; it's ok to return nothing if nothing is relevant to the question.
    As a reminder, the original queries were:
    \(queriesList)
    
    Choose file snippets by responding in this exact JSON format:
    ```
    interface Response {
        snippets: { 
            path: string, 
            ranges: string[],
            score: number // 0-100 how relevant is this file?
        }[] 
        // `ranges` is an array of line ranges in format "START-END", like 0-100
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
                try items.append((
                    snippet.score,
                    FileSnippet(path: path, lineStart: start, linesCount: end - start + 1)
                ))
            }
        }
    }
    return items
}

private func parseRange(_ str: String) -> (Int, Int)? {
    // Written by Phil
    let parts = str.split(separator: "-").compactMap({ Int($0) })
    if parts.count == 2 {
        return (parts[0], parts[1])
    }
    return nil
}

//import ChatToys
//import Foundation
//
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
//
//func codeSearch2(query: String, folder: URL, context: ToolContext) async throws -> [ContextItem] {
//    // Split file list into chunks
//    // With each chunk, ask for list of relevant files and GREPS
//    // With relevant file snippets, ask for RELEVANT SNIPPETS and NEW QUESTIONS
//
//}
//
//private func _codeSearch2(queries: [String], folder: URL, treePortion: String, context: ToolContext) async throws -> (snippets: [FileSnippetRange], nextQuestions: [String]) {
//    let initialPrompt = """
//    Act as an expert engineer pair-programming with another engineer in an unfamiliar codebase.
//    The other programmer will write the code, but they can only read parts of the codebase that you provide to them.
//    They have passed you a question or topic, relevant to a coding task they're doing.
//    It is your job to dive into the codebase and bring them snippets of code that they'll be able to use.
//    You will be evaluated on the comprehensiveness of the snippets you provide, and the signal to noise ratio; don't make them sift through too much junk.
//    
//    You will be given a prompt that they need you to answer, and a list of files. (This may not be all the files in the codebase).
//    First, you will create an initial set of relevant content by:
//    - Choosing files to read
//    - Choosing Regex searches to execute
//    Then, you'll be shown the results, and be asked to choose relevant lines ("snippets") to show the engineer. 
//    Finally, if the code snippets are incomplete and do not tell you all you need to know, you'll be able to provide an additional list of questions.
//
//    [BEGIN FILE TREE]
//    \(treePortion)
//    [END FILE TREE]
//    
//    [[CONTEXT]]
//    
//    Next, the engineer will provide their search prompt:
//    > \(query)
//    
//    Now, your job is to use JSON to write a request for relevant information. Remember, aim to collect relevant information, but not too much -- only pick stuff that seems really relevant!
//    
//    Respond using JSON, in this exact format:
//    ```
//    {
//        read_files: [String] // Most relevant file paths to read. Can be empty if no relevant paths. Most relevant first.
//        greps: [String] // Regexes, in NSRegularExpression format, to search. 0, 1 or a few. Write loose regexes to find definitions, etc. Only use as a last resort if read_files isn't a good option.
//    }
//    ```
//    """
//
//    struct RelevanceResp: Codable {
//        var read_files: [String]
//        var greps: [String]
//    }
//
//    var messages = [
//        LLMMessage(role: .user, content: initialPrompt),
//    ]
//
//    let llm = try LLMs.quickModel()
//    let relevantItems = try await llm.completeJSONObject(prompt: messages, type: RelevanceResp.self)
//    var snippetRanges: [FileSnippetRange] = []
//    for file in relevantItems.read_files.prefix(5) {
//        let resolvedPath = try context.resolvePath(file)
//        snippetRanges.append(.init(path: resolvedPath, lineRangeStart: 0, lineRangeEnd: 1000))
//        context.log(.readFile(resolvedPath.lastPathComponent))
//    }
//    for grep in relevantItems.greps.prefix(3) {
//        snippetRanges += try await grepToSnippetRanges(pattern: grep, folder: folder, linesAroundMatchToInclude: 2, limit: 10)
//        context.log(.grepped(grep))
//    }
//    if snippetRanges.count == 0 {
//        return ([], [])
//    }
//    let snippets: String = try FileSnippetRange.mergeOverlaps(ranges: snippetRanges)
//        .map({ try FileSnippet(path: $0.path, lineStart: $0.lineRangeStart, linesCount: $0.lineRangeEnd) })
//        .map(\.asString)
//        .joined(separator: "\n\n")
//
//    messages.append(.init(role: .user, content: snippets))
//    messages.append(.init(role: .user, content: """
//    OK, great. There's some data you requested. Keep in mind I've only shown you the first 1000 lines of each file, and the first 10 matches for each grep.
//    
//    Now, your job is to think back to the engineer's original question, and extract
//    the most relevant parts of this file. Extract ALL parts of the file that would be necessary
//    to answer the question and make a related code edit.
//    ONLY include useful, valuable data; it's ok to return nothing if nothing is relevant to the question.
//    As a reminder, the original query was:
//    > \(query)
//    
//    In addition, you should append any REMAINING QUESTIONS you have after viewing these files.
//    Maybe there's a crucial struct that you need the definition for. Maybe you need to find callers of a function, so they can be modified too.
//    
//    Respond in this exact JSON format:
//    ```
//    {
//        snippets: Snippet[],
//        next_questions: string[]
//    }
//    ```
//    """))
//}
