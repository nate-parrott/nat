import Foundation
import ChatToys

enum AgentStatus: Equatable, Codable {
    case none
    case running(UUID)
    case paused(UUID)
    case stoppedWithError(String)
    
    var currentRunId: UUID? {
        switch self {
        case .running(let uuid), .paused(let uuid):
            return uuid
        case .stoppedWithError, .none: return nil
        }
    }
}

struct ThreadModel: Equatable, Codable {
    var steps = [Step]()
    var status = AgentStatus.none

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
            var psuedoFunctionResponse: [ContextItem]?

            // Logs for each function call (by id)
            var functionCallLogs = [String: [UserVisibleLog]]()
            var psuedoFunctionLogs = [UserVisibleLog]()
            
            var allLogs: [UserVisibleLog] {
                psuedoFunctionLogs + functionCallLogs.values.flatMap(\.self)
            }
            
            var isComplete: Bool {
                if initialResponse.functionCalls.count == 0 {
                    return psuedoFunctionResponse != nil
                }
                return computerResponse.count == initialResponse.functionCalls.count
            }
        }
    }
}

// Used for events that will render cards into the feed
enum UserVisibleLog: Equatable, Codable {
    case readFile(URL)
    case grepped(String)

    case edits(Edits)
    struct Edits: Equatable, Codable {
        var paths: [URL]
        var accepted: Bool
        var comment: String?
    }
    
    case webSearch(String)

//    case wroteFile(URL)
    case deletedFile(URL)  // Added this case
    case codeSearch(String)
    case usingEditCleanupModel(URL)
        
    case listedFiles
    case tokenUsage(prompt: Int, completion: Int, model: String)
    case effort(String)
    case readUrls([String])

    case toolWarning(String)
    case toolError(String)
    
    case terminal(command: String)
    case terminalSnapshot(String) // a snapshot of the terminal at a certain time after performing a command
    
    case retrievedLogs(Int)
    
    case usedWebview
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
            if step.computerResponse.count > 0 {
                // We have responses to function calls. We may also need to jam a psuedo-fn response in there:
                var respMsg = TaggedLLMMessage(functionResponses: step.computerResponse.map(\.asTaggedLLMResponse))
                if let psuedoFunctionResponse = step.psuedoFunctionResponse {
                    respMsg.functionResponses[0].content.insert(contentsOf: psuedoFunctionResponse, at: 0)
                }
                messages.append(respMsg)
            } else if let psuedoFunctionResponse = step.psuedoFunctionResponse {
                messages.append(.init(role: .user, content: psuedoFunctionResponse))
            } else {
                fatalError("Missing fn response for step \(step)")
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
    // TODO: summarize old messages
    func omitOldMessages(keepFirstN: Int = 4, keepLastN: Int = 40, round: Int = 7) -> [TaggedLLMMessage] {
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
    
    func truncateOldMessages(keepFirstN: Int = 4, keepLastN: Int = 40, round: Int = 7) -> [TaggedLLMMessage] {
        if count <= keepFirstN + keepLastN {
            return self
        }
        let cutoff = Swift.max(keepFirstN, (count - keepLastN).round(round))
        var truncated = self
        for i in keepFirstN..<cutoff {
            truncated[i].shorten()
        }
        return truncated
    }
}

extension TaggedLLMMessage {
    mutating func shorten() {
        // TODO: truncate function calls?
        for i in functionResponses.indices {
            functionResponses[i].content = truncateContent(functionResponses[i].content)
        }
        content = truncateContent(content)
    }
}

func truncateContent(_ items: [ContextItem]) -> [ContextItem] {
    // Keep only first, remove images
    let items = items.compactMap { item -> ContextItem? in
        switch item {
        case .text(let string):
            return ContextItem.text(string.truncateMiddleWithEllipsis(chars: 200))
        case .fileSnippet:
            return ContextItem.omission("[Old file content omitted; request again if you need]")
        case .image: return nil
        case .systemInstruction(let string):
            return ContextItem.systemInstruction(string.truncateMiddleWithEllipsis(chars: 200))
        case .textFile:
            // TODO: better
            return ContextItem.omission("[Old file content omitted; request again if you need]")
        case .url(let url, _):
            return .url(url, pageContent: nil)
        case .largePaste(let string):
            return .largePaste(string.truncateMiddleWithEllipsis(chars: 200))
        case .omission(let string):
            return .omission(string)
        case .proactiveContext(title: let title, content: let content):
            return .proactiveContext(title: title, content: content.truncateMiddleWithEllipsis(chars: 200))
        }
    }
    if let first = items.first {
        return [first]
    }
    return [.omission("Old content omitted")]
}

extension Int {
    func round(_ div: Int) -> Int {
        quotientAndRemainder(dividingBy: div).quotient * div
    }
}
