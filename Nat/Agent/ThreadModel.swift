import Foundation
import ChatToys

enum AgentStatus: Equatable, Codable {
    case none
    case running
    case paused
    case stoppedWithError(String)
}

struct ThreadModel: Equatable, Codable {
    var steps = [Step]()
    var status = AgentStatus.none
    var cancelCount = 0 // HACK: to allow use to break out of the checkCancelOrPause loop when cancelling

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
    case usingEditCleanupModel(String)
    case listedFiles
    case tokenUsage(prompt: Int, completion: Int, model: String)
    case effort(String)

    case toolWarning(String)
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
    var asTaggedLLMMessages: [TaggedLLMMessage] {
        var messages: [TaggedLLMMessage] = [initialRequest]
        for step in toolUseLoop {
            messages.append(step.initialResponse)
            messages.append(TaggedLLMMessage(functionResponses: step.computerResponse.map(\.asTaggedLLMResponse)))
            if let psuedoFunctionResponse = step.psuedoFunctionResponse {
                messages.append(psuedoFunctionResponse)
            }
        }
        if let assistantMessageForUser {
            messages.append(assistantMessageForUser)
        }
        return messages

    }
    var asLLMMessages: [LLMMessage] {
        asTaggedLLMMessages.map { $0.asLLMMessage() }
    }
}

extension Array where Element == TaggedLLMMessage {
    // Typically the system message is not included in the array at this point
    func truncateTaggedLLMessages(keepFirstN: Int = 2, keepLastN: Int = 10, round: Int = 7) -> [TaggedLLMMessage] {
        if count <= keepFirstN + keepLastN {
            return self
        }
        let cutoff = Swift.max(keepFirstN, (count - keepLastN).round(round))
        var remaining = Array(self[..<keepFirstN] + [TaggedLLMMessage(role: .system, content: [.text("[Old messages omitted]")])] + self[cutoff...])
        remaining[keepFirstN - 1].functionCalls = [] // Cannot be any function calls b/c we won't be responding to them

        // Modify the first item after the cut
        remaining[keepFirstN + 1].functionResponses = [] // Cannot be any function responses b/c there was nothing to respond to
        if remaining[keepFirstN + 1].content.isEmpty {
            remaining[keepFirstN + 1].content = [.text("[Omitted]")]
        }
        return remaining.asArray
    }
}

extension Int {
    func round(_ div: Int) -> Int {
        quotientAndRemainder(dividingBy: div).quotient * div
    }
}
