import Foundation
import ChatToys

struct ThreadModel: Equatable, Codable {
    var steps = [Step]()
    var isTyping = false
    var lastError: String?

    struct Step: Equatable, Codable, Identifiable {
        var id: String
        // Every sequence begins with a user request, continues through a series of tool calls, and ends with an open-ended message from the model without tool calls
        var initialRequest: TaggedLLMMessage // Must be role=user
        var toolUseLoop: [ToolUseStep]
        var assistantMessageForUser: TaggedLLMMessage? // Message with no function calls and role=assistant

        struct ToolUseStep: Equatable, Codable {
            var initialResponse: TaggedLLMMessage // Will include >= 1 fn call, unless psuedo-function

            // These two are mutually exclusive
            var computerResponse: [TaggedLLMMessage.FunctionResponse]
            var psuedoFunctionResponse: TaggedLLMMessage?

            var userVisibleLogs = [UserVisibleLog]()

            var isComplete: Bool {
                computerResponse.count > 0 || psuedoFunctionResponse != nil
            }
        }
    }
}

// Used for events that will render cards into the feed
enum UserVisibleLog: Equatable, Codable {
    case readFile(String)
    case grepped(String)

    case editedFile(String)
    case rejectedEdit(String)
    case requestedChanges(String)
    case webSearch(String)
    case info(String)

    case wroteFile(String)
    case deletedFile(String)  // Added this case
    case codeSearch(String)
    case listedFiles
    case tokenUsage(prompt: Int, completion: Int, model: String)
    case effort(String)

    case toolError(String)
    case terminal(command: String)
}

extension ThreadModel.Step {
    // incomplete thread steps reflect actions that failed partway thru. We can't send these in a new thread because they miss part of the necessary message responses
    var isComplete: Bool {
        return assistantMessageForUser != nil && toolUseLoop.allSatisfy({ $0.isComplete })
    }
}

extension ThreadModel.Step {
    var asLLMMessages: [LLMMessage] {
        var messages: [LLMMessage] = [initialRequest.asLLMMessage()]
        for step in toolUseLoop {
            messages.append(step.initialResponse.asLLMMessage())
            messages.append(LLMMessage(functionResponses: step.computerResponse.map(\.asLLMResponse)))
            if let psuedoFunctionResponse = step.psuedoFunctionResponse {
                messages.append(psuedoFunctionResponse.asLLMMessage())
            }
        }
        if let assistantMessageForUser {
            messages.append(assistantMessageForUser.asLLMMessage())
        }
        return messages
    }
}
