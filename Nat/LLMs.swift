import ChatToys
import Foundation

enum LLMs {
    static func smartAgentModel() throws -> ChatGPT {
        try ChatGPT(credentials: .init(apiKey: openrouterKey()), options: .init(temp: 1, model: .custom("anthropic/claude-3.5-sonnet:beta", 200_000), baseURL: .openRouterOpenAIChatEndpoint, headers: additionalHeaders))
    }

    static var fakeFunctions: Bool {
        false // set true for use with deepseek
    }
    
    static var additionalHeaders: [String: String] {
        [
            "HTTP-Referer": "https://github.com/nate-parrott/nat",
            "X-Title": "Nat for Xcode",
        ]
    }

    static func quickModel() throws -> ChatGPT {
        try ChatGPT(credentials: .init(apiKey: openrouterKey()), options: .init(temp: 1, model: .custom("openai/gpt-4o-mini", 1_000_000), baseURL: .openRouterOpenAIChatEndpoint, headers: additionalHeaders))
    }

    static func applierModel() throws -> ChatGPT {
        try ChatGPT(credentials: .init(apiKey: openrouterKey()), options: .init(temp: 0, model: .custom("openai/gpt-4o-mini", 1_000_000), baseURL: .openRouterOpenAIChatEndpoint, headers: additionalHeaders))
    }


    static func openrouterKey() throws -> String {
        if let key = DefaultsKeys.openrouterKey.stringValue().nilIfEmpty {
            return key
        }
        throw LLMError.noOpenRouterAPIKey
    }
}

private enum LLMError: Error {
    case noOpenRouterAPIKey
}
