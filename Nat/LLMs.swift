import ChatToys
import Foundation

enum LLMs {
    static func smartAgentModel() throws -> FunctionCallingLLM {
        try ChatGPT(credentials: .init(apiKey: openrouterKey()), options: .init(temp: 1, model: .custom("anthropic/claude-3.5-sonnet:beta", 200_000)))
    }

    static func quickModel() throws -> FunctionCallingLLM {
        try ChatGPT(credentials: .init(apiKey: openrouterKey()), options: .init(temp: 1, model: .custom("google/gemini-flash-1.5", 1_000_000)))
    }

    private static func openrouterKey() throws -> String {
        if let key = DefaultsKeys.openrouterKey.stringValue().nilIfEmpty {
            return key
        }
        throw LLMError.noOpenRouterAPIKey
    }
}

private enum LLMError: Error {
    case noOpenRouterAPIKey
}
