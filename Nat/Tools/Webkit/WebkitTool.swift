import Foundation
import ChatToys
import AnyCodable

struct WebkitTool: Tool {
    enum Errors: Error {
        case noDocument
    }
    
    var functions: [LLMFunction] {
        [webkitRunJSFn.asLLMFunction, webkitShowWebviewToUserFn.asLLMFunction]
    }
    
    // Function 1: Run JS Expression
    let webkitRunJSFn = TypedFunction<RunJSExpressionArgs>(
        name: "webkitRunJS",
        description: "Runs a potentially-async JS expression (or self-calling FN) and returns the results to the agent. Your webkit webview is a persistent sandbox where you can run code and show things to the user. It is not intended to be navigated; it's on about:blank but you can use JS to modify the DOM. Cross-origin requests are allowed.",
        type: RunJSExpressionArgs.self
    )
    
    struct RunJSExpressionArgs: FunctionArgs {
        let expression: String
        
        static var schema: [String: LLMFunction.JsonSchema] {
            ["expression": .string(description: "JavaScript expression to evaluate. Can be async.")]
        }
    }
    
    // Function 2: Present To User
    let webkitShowWebviewToUserFn = TypedFunction<ShowWebviewToUserArgs>(
        name: "webkitShowWebviewToUser",
        description: "Shows the webview to the user as a modal sheet.",
        type: ShowWebviewToUserArgs.self
    )
    
    struct ShowWebviewToUserArgs: FunctionArgs {
        static var schema: [String: LLMFunction.JsonSchema] {
            [:] // No args needed
        }
    }
    
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse? {
        guard let doc = context.document else {
            throw Errors.noDocument
        }
        let webSession = await doc.getOrCreateWebSession()
        
        if let args: RunJSExpressionArgs = webkitRunJSFn.checkMatch(call: call) {
            do {
                print("[Webkit] run: \(args.expression)")
                await context.log(.usedWebview)
                let result = try await webSession.evaluateAsyncJavaScript(args.expression)
                print("[Webkit] result: \(result ?? "")")
                if let coded = result as? AnyCodable {
                    return call.response(text: coded.jsonString.truncateMiddleWithEllipsis(chars: 5000))
                } else if let result {
                    let resultDesc = "\(result)".truncateMiddleWithEllipsis(chars: 5000)
                    return call.response(text: resultDesc)
                } else {
                    return call.response(text: "[Returned null or undefined]")
                }
            } catch {
                print("[Webkit] Error: \(error)")
                return call.response(text: "Error: \(error)")
            }
        }
        
        if let _: ShowWebviewToUserArgs = webkitShowWebviewToUserFn.checkMatch(call: call) {
            await webSession.present()
            return call.response(text: "OK")
        }
        
        return nil
    }
}
