import ChatToys
import Foundation

enum LLMs {
    static func smartAgentModel() throws -> ChatGPT {
        try ChatGPT(credentials: .init(apiKey: openrouterKey()), options: .init(temp: 1, model: .custom("anthropic/claude-3.5-sonnet:beta", 200_000), baseURL: .openRouterOpenAIChatEndpoint))
//        try ChatGPT(credentials: .init(apiKey: openrouterKey()), options: .init(temp: 1, model: .custom("deepseek/deepseek-r1:nitro", 160_000), printToConsole: true, baseURL: .openRouterOpenAIChatEndpoint))
//        try ChatGPT(credentials: .init(apiKey: openrouterKey()), options: .init(temp: 1, model: .custom("google/gemini-2.0-flash-thinking-exp:free", 1_000_000), baseURL: .openRouterOpenAIChatEndpoint))
    }

    static var fakeFunctions: Bool {
        false // set true for use with deepseek
    }

    static func quickModel() throws -> ChatGPT {
//        try ChatGPT(credentials: .init(apiKey: openrouterKey()), options: .init(temp: 1, model: .custom("google/gemini-flash-1.5", 1_000_000), baseURL: .openRouterOpenAIChatEndpoint))

        try ChatGPT(credentials: .init(apiKey: openrouterKey()), options: .init(temp: 1, model: .custom("openai/gpt-4o-mini", 1_000_000), baseURL: .openRouterOpenAIChatEndpoint))

//        try ChatGPT(credentials: .init(apiKey: openrouterKey()), options: .init(temp: 1, model: .custom("meta-llama/llama-3.3-70b-instruct", 1_000_000), baseURL: .openRouterOpenAIChatEndpoint))
    }

    static func applierModel() throws -> ChatGPT {
        try ChatGPT(credentials: .init(apiKey: openrouterKey()), options: .init(temp: 1, model: .custom("amazon/nova-micro-v1", 128_000), baseURL: .openRouterOpenAIChatEndpoint))
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
