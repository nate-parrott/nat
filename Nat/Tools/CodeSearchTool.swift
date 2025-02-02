import Foundation
import ChatToys

struct CodeSearchTool: Tool {
    var functions: [LLMFunction] {
        [Self.fn.asLLMFunction]
    }

    static let fn = TypedFunction<Args>(name: "code_search", description: "Searches codebase using agentic AI search _and_ regex search, and returns relevant snippets.", type: Args.self)

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
        if let args = Self.fn.checkMatch(call: call) {
            let effort = args.parsedEffort
            // Append search terms in ui:
            if effort != .one {
                await context.log(.effort("Searching with effort: \(args.parsedEffort.rawValue)"))
            }
            for q in args.questions ?? [] {
                await context.log(.codeSearch(q))
            }
            for q in args.regexes ?? [] {
                await context.log(.grepped(q))
            }

            guard let folderURL = context.activeDirectory else {
                return call.response(text: "Tell the user they need to choose a folder before you can search the codebase.")
            }

            async let answers_: [ContextItem] = try await codeSearch2(queries: args.questions ?? [], folder: folderURL, context: context, effort: effort).snippets
                .map({ ContextItem.fileSnippet($0) })

            async let grepSnippets_: [[FileSnippet]] = try await args.regexes?.concurrentMapThrowing({ pattern in
                try await grepToSnippets(pattern: pattern, folder: folderURL, linesAroundMatchToInclude: 3, limit: effort.grepLimit)
            }) ?? []

            var output = [ContextItem]()
            output += try await answers_
            for (regex, snippets) in try await zip(args.regexes ?? [], grepSnippets_) {
                output.append(.text("# \(snippets.count) search results for \(regex) (limit \(effort.grepLimit)):"))
                for snippet in snippets {
                    output.append(.fileSnippet(snippet))
//                    outputLines.append(snippet.asString(withLineNumbers: Constants.useLineNumbers))
                }
            }

            output.append(.text("^ Code search results above. Use additional code_search calls, read_file or other tools to get more information if you need it."))
            return call.response(items: output)
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
