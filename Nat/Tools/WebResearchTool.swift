import Foundation
import ChatToys

struct WebResearchTool: Tool {
    var functions: [LLMFunction] {
        [Self.fn.asLLMFunction]
    }
    
    static let fn = TypedFunction<Args>(name: "web_research", description: "Takes a specific prompt and uses perplexity/llama-3.1-sonar-large-128k-online to fetch answers from the web", type: Args.self)
    
    struct Args: FunctionArgs {
        var prompt: String
        
        static var schema: [String: LLMFunction.JsonSchema] {
            [
                "prompt": .string(description: "A SPECIFIC piece of information, sample code or api defs that we want to pull from the web")
            ]
        }
    }
    
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse? {
        if let args = Self.fn.checkMatch(call: call) {
            do {
                await context.log(.webSearch(args.prompt))
                
                let llm = try ChatGPT(
                    credentials: .init(apiKey: LLMs.openrouterKey()),
                    options: .init(
                        temp: 0.7,
                        model: .custom("perplexity/llama-3.1-sonar-large-128k-online", 128_000),
                        baseURL: .openRouterOpenAIChatEndpoint
                    )
                )
                
                let messages = [
                    LLMMessage(role: .system, content: "You are a web research assistant. Provide accurate, factual information based on the user's query. Focus on specific details, code examples, and API definitions. Be concise and precise."),
                    LLMMessage(role: .user, content: args.prompt)
                ]
                
                var result = ""
                for try await partial in llm.completeStreaming(prompt: messages) {
                    result = partial.content
                }
                
                return call.response(text: result)
            } catch {
                return call.response(text: "Web research failed: \(error)")
            }
        }
        return nil
    }
}
