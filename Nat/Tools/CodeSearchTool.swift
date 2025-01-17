import Foundation
import ChatToys

struct CodeSearchTool: Tool {
    var functions: [LLMFunction] {
        [fn.asLLMFunction]
    }

    let fn = TypedFunction<Args>(name: "code_search", description: "This search assistant explores the codebase and gathers code snippets for you based on a prompt, like 'how to add a new source' or 'examples of HTML parsing'", type: Args.self)

    struct Args: FunctionArgs {
        var questions: [String]

        static var schema: [String: LLMFunction.JsonSchema] {
            [
                "questions": .array(description: nil, itemType: .string(description: "concise list of SPECIFIC pieces of information you need. Don't use more than you need."))
            ]
        }
    }

    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> LLMMessage.FunctionResponse? {
        if let args = fn.checkMatch(call: call) {
            for q in args.questions {
                context.log(.codeSearch(q))
            }
            guard let folderURL = context.activeDirectory else {
                return call.response(text: "Tell the user they need to choose a folder before you can search the codebase.")
            }
            let answers = try await args.questions.concurrentMapThrowing { prompt in
                do {
                    let text = try await codeSearch(prompt: prompt, folderURL: folderURL, emitLog: context.log)
                    return "# Results for '\(prompt)'\n\(text)"
                } catch {
                    context.log(.toolError("Error on code_search('\(prompt)'): \(error)"))
                    return "code_search query '\(prompt)' failed with error: \(error)"
                }
            }
            return call.response(text: answers.joined(separator: "\n\n"))
        }
        return nil
    }
}

