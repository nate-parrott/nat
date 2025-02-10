import Foundation
import ChatToys

extension Document {
    struct CleanThreadResponse: Codable {
        var summary: String
        var relevantFiles: [String]
        var status: String
    }
    
    @MainActor
    func cleanThread(reason: String) async throws -> CleanThreadResponse {
        guard let thread = store.model.thread else {
            throw DocumentError.noThread
        }
        
        // Convert to LLM messages, filtering out incompletes
        let llmMessages = thread.steps
            .filter { $0.isComplete }
            .flatMap(\.asTaggedLLMMessages)
        
        // Create prompt for summarization
        let prompt = """
        Analyze this conversation and create a summary focused on:
        1. What was requested (initial request and clarifications)
        2. Code changes made - include specific functions/methods/files
        3. Important decisions and approaches taken
        4. What is DONE vs NOT DONE YET
        \(reason)
        
        Output ONLY a JSON object with these fields:
        {
            "summary": "Dense technical summary focused on code changes and decisions",
            "relevantFiles": ["Array of 1-5 most important file paths"],
            "status": "complete" or "in_progress"
        }
        """
        
        var messages = llmMessages.map(\.asLLMMessage)
        messages.append(LLMMessage(role: .user, content: prompt))
        let llm = try LLMs.quickModel()
        return try await llm.completeJSONObject(prompt: messages, type: CleanThreadResponse.self)
    }
}

enum DocumentError: Error {
    case noThread
}