import Foundation
import ChatToys

struct ThreadModel: Equatable, Codable {
    var steps = [Step]()
    var isTyping = false
    var lastError: String?

    struct Step: Equatable, Codable {
        var id: String
        // Every sequence begins with a user request, continues through a series of tool calls, and ends with an open-ended message from the model without tool calls
        var initialRequest: LLMMessage // Must be role=user
        var toolUseLoop: [ToolUseStep]
        var assistantMessageForUser: LLMMessage? // Message with no function calls and role=assistant

        struct ToolUseStep: Equatable, Codable {
            var initialResponse: LLMMessage // Will include >= 1 fn call
            var computerResponse: [LLMMessage.FunctionResponse]
        }
    }
}

extension ThreadModel.Step {
    // incomplete thread steps reflect actions that failed partway thru. We can't send these in a new thread because they miss part of the necessary message responses
    var isComplete: Bool {
        return assistantMessageForUser != nil && toolUseLoop.allSatisfy({ $0.computerResponse.count > 0 })
    }
}

extension ThreadModel.Step {
    var asLLMMessages: [LLMMessage] {
        var messages = [initialRequest]
        for step in toolUseLoop {
            messages.append(step.initialResponse)
            messages.append(LLMMessage(functionResponses: step.computerResponse))
        }
        if let assistantMessageForUser {
            messages.append(assistantMessageForUser)
        }
        return messages
    }
}
