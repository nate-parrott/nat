import Foundation
import ChatToys

extension Document {
    @MainActor
    func cleanThread(reason: String) async throws -> String {
        guard let thread = store.model.thread else {
            throw DocumentError.noThread
        }
        
        // Convert to LLM messages, filtering out incompletes
        let llmMessages = thread.steps
            .filter { $0.isComplete }
            .flatMap(\.asTaggedLLMMessages)
        
        // Create prompt for summarization
        let systemPrompt = """
        Your job is to summarize this conversation and the work done so far. Focus on:
        1. What the user actually ASKED FOR (the initial request and any clarifications)
        2. What code changes have been made - include specific functions/methods/files when relevant
        3. Any important decisions or approaches taken
        4. What is DONE vs NOT DONE YET
        \(reason)
        
        Return a single JSON object with these fields:
        - summary: A dense technical summary, focused on code changes made and important decisions
        - relevantFiles: Array of 1-5 most important file paths that were edited or crucial to understanding the changes
        - status: "complete" or "in_progress"
        """
        
        let finalMsg = TaggedLLMMessage(role: .user, content: [.systemInstruction(systemPrompt)])
        var messages = [TaggedLLMMessage(role: .system, content: [.text("You are a technical summarizer.")])]
        messages.append(contentsOf: llmMessages)
        messages.append(finalMsg)
        
        // Create a temporary agent to summarize
        let agent = Agent(name: "summarizer", 
                         maxIterations: 1,
                         llm: .openai(.gpt4_turbo_preview), 
                         tools: [], // No tools needed for summarization
                         fakeFunctions: false,
                         folder: URL(fileURLWithPath: ""),
                         autorun: true,
                         document: nil)
        
        let result = try await agent.send(
            message: finalMsg,
            maxTokens: 2048,
            systemPrompt: systemPrompt,
            existingMessages: messages
        ).steps.last?.assistantMessageForUser?.asPlainText ?? ""
        
        return result
    }
}

enum DocumentError: Error {
    case noThread
}