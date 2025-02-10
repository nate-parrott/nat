import Foundation
import ChatToys

struct CleanThreadResponse: Codable {
    var summary: String
    var relevantFiles: [String]
    var status: String
}

extension Document {
    func cleanThread() async throws {
        stop()
        store.model.cleaning = true
        do {
            let summary = try await self.getThreadSummary()
            Swift.print("Summary:\n\(summary)")
            store.modify { state in
                state.cleaning = nil
                state.thread = ThreadModel(steps: [
                    ThreadModel.Step(
                        id: UUID().uuidString,
                        initialRequest: TaggedLLMMessage(role: .user, content: [
                            .text("Let me catch you up on what we're doing with a summary:"),
                            .largePaste(summary.jsonString)
                        ]),
                        toolUseLoop: [],
                        assistantMessageForUser: TaggedLLMMessage(role: .assistant, content: [.text("OK, let's continue.")]))
                ], status: .none)
            }
        } catch {
            // TODO: alert
            Swift.print("Error cleaning thread: \(error)")
            store.model.cleaning = nil
        }
    }
}

extension AgentThreadStore {
    @MainActor
    func getThreadSummary() async throws -> CleanThreadResponse {
        var thread = await readThreadModel()
        thread.fixIncompleteSteps()
        let llmMessages = thread.steps
            .filter { $0.isComplete }
            .flatMap(\.asTaggedLLMMessages)
            .truncateOldMessages()
            .byDroppingRedundantContext()
        
        // Create prompt for summarization
        let prompt = """
        Analyze this conversation and create a summary focused on:
        1. What was requested (initial request and clarifications)
        2. Code changes made - include specific functions/methods/files
        3. Important decisions and approaches taken
        4. What is DONE vs NOT DONE YET
        
        Output ONLY a JSON object with these fields:
        {
            "summary": "Dense technical summary focused on code changes and decisions",
            "relevantFiles": ["Array of 1-5 most important file paths"],
            "status": "complete" or "in_progress"
        }
        """
        
        var messages = llmMessages.map { $0.asLLMMessage().byConvertingFunctionsToFakeFunctions }
        messages.append(LLMMessage(role: .user, content: prompt))
        let llm = try LLMs.smartAgentModel()
        return try await llm.completeJSONObject(prompt: messages, type: CleanThreadResponse.self)
    }
}

enum DocumentError: Error {
    case noThread
}
