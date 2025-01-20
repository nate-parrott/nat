import Foundation
import ChatToys

struct CodeSearchTool: Tool {
    var functions: [LLMFunction] {
        [fn.asLLMFunction]
    }

    let fn = TypedFunction<Args>(name: "code_search", description: "Searches codebase using agentic AI search _and_ regex search, and returns relevant snippets.", type: Args.self)

    struct Args: FunctionArgs {
        var questions: [String]?
        var regexes: [String]?
        var effort: Float?

        var parsedEffort: CodeSearchEffort {
            CodeSearchEffort(rawValue: Int(effort ?? 1)) ?? .one
        }

        static var schema: [String: LLMFunction.JsonSchema] {
            [
                "questions": .array(description: nil, itemType: .string(description: "concise list of SPECIFIC pieces of information you need. Don't use more than you need.")),
                "regexes": .array(description: nil, itemType: .string(description: "if you know the name of a symbol or string to find, you can also perform a string search. Use NSRegularExpression format. No more than 2.")),
                "effort": .number(description: "Int in range 1...3. Start with effort=1 (fastest), then use higher effort if you don't find what you need.")
            ]
        }
    }

    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse? {
        if let args = fn.checkMatch(call: call) {
            let effort = args.parsedEffort
            // Append search terms in ui:
            if effort != .one {
                context.log(.effort("Searching with effort: \(args.parsedEffort.rawValue)"))
            }
            for q in args.questions ?? [] {
                context.log(.codeSearch(q))
            }
            for q in args.regexes ?? [] {
                context.log(.grepped(q))
            }

            guard let folderURL = context.activeDirectory else {
                return call.response(text: "Tell the user they need to choose a folder before you can search the codebase.")
            }

            async let answers_: [String] = try await codeSearch2(queries: args.questions ?? [], folder: folderURL, context: context, effort: effort)
                .map({ $0.asString })

            async let grepSnippets_: [[FileSnippet]] = try await args.regexes?.concurrentMapThrowing({ pattern in
                try await grepToSnippets(pattern: pattern, folder: folderURL, linesAroundMatchToInclude: 3, limit: effort.grepLimit)
            }) ?? []

            var outputLines = [String]()
            outputLines += try await answers_
            for (regex, snippets) in try await zip(args.regexes ?? [], grepSnippets_) {
                outputLines.append("# \(snippets.count) search results for \(regex) (limit \(effort.grepLimit)):")
                for snippet in snippets {
                    outputLines.append(snippet.asString)
                }
            }

            outputLines.append("^ Code search results above. Use additional code_search calls, read_file or other tools to get more information if you need it.")
            return call.response(text: outputLines.joined(separator: "\n\n"))

//            let answers = try await args.questions.concurrentMapThrowing { prompt in
//                do {
//                    let text = try await codeSearch(prompt: prompt, folderURL: folderURL, emitLog: context.log)
//                    return "# Results for '\(prompt)'\n\(text)"
//                } catch {
//                    context.log(.toolError("Error on code_search('\(prompt)'): \(error)"))
//                    return "code_search query '\(prompt)' failed with error: \(error)"
//                }
//            }
//            return call.response(text: answers.joined(separator: "\n\n"))
        }
        return nil
    }
}

enum CodeSearchEffort: Int {
    case one = 1
    case two = 2
    case three = 3

    var grepLimit: Int {
        switch self {
        case .one: return 5
        case .two: return 10
        case .three: return 20
        }
    }

    /*
     static let codeSearchFilesToReadPerChunk = 8
     static let codeSearchLinesToRead = 1000
     static let codeSearchToolMaxSnippetsToReturn = 20
     */

    var filesToReadPerChunk: Int {
        switch self {
        case .one: return 4
        case .two: return 8
        case .three: return 12
        }
    }

    var linesToRead: Int {
        switch self {
        case .one: return 1000
        case .two: return 1000
        case .three: return 2000
        }
    }

    var maxSnippetsToReturn: Int {
        switch self {
        case .one:
            return 5
        case .two:
            return 10
        case .three:
            return 15
        }
    }
}
