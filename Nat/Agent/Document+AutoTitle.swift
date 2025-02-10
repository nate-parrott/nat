//
//  Document+AutoTitle.swift
//  Nat
//

import Foundation
import ChatToys

struct AutoTitleResponse: Codable {
    var title: String
}

// MARK: - String Path Component Sanitization
extension String {
    /// Sanitizes a string for use as a filename
    var asPathComponent: String {
        lowercased()
            .components(separatedBy: CharacterSet.urlPathAllowed.inverted)
            .joined()
            .replacingOccurrences(of: " ", with: "_")
    }
}

// MARK: - URL Path Helpers
extension URL {
    /// Returns a URL with an incrementing number suffix if needed to avoid conflicts
    func appendingUniqueComponent(_ component: String, extension ext: String? = nil) -> URL {
        var url = self
        var attempts = 0
        
        // Build candidate URL
        func nextCandidate() -> URL {
            let suffix = attempts == 0 ? "" : "_\(attempts)"
            let finalComponent = component + suffix
            return url.appendingPathComponent(finalComponent)
                .appendingPathExtension(ext ?? "")
        }
        
        // Try until we find a unique name
        var candidate = nextCandidate()
        while FileManager.default.fileExists(atPath: candidate.path) {
            attempts += 1
            candidate = nextCandidate()
        }
        
        return candidate
    }
}

extension Document {
    func generateAndApplyAutoTitle() async throws {
        // Only auto-title unsaved documents
        guard !store.model.thread.steps.isEmpty, fileURL == nil else { return }
        
        // Get the first message
        let firstMessage = store.model.thread.steps[0].initialRequest.asPlainText.truncateMiddleWithEllipsis(chars: 1000)
        
        // Create prompt for title generation
        let prompt = """
        Generate a concise, descriptive title for this chat, based on the first message. The title should be:
        - Short (2-5 words)
        - Technical and specific
        - Focused on the main task/goal
        
        First message:
        \(firstMessage)
        
        Output ONLY a JSON object like:
        {
            "title": "The generated title"
        }
        """
        
        // Generate title
        guard let llm = try? LLMs.smartAgentModel() else {
            throw NSError(domain: "AutoTitle", code: 1, userInfo: [NSLocalizedDescriptionKey: "No API key configured"])
        }
        
        let response = try await llm.completeJSONObject(prompt: [LLMMessage(role: .user, content: prompt)], type: AutoTitleResponse.self)
        
        // Generate unique path on desktop
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let saveURL = desktop.appendingUniqueComponent(response.title.asPathComponent, extension: "nat")
        
        try await save(to: saveURL, ofType: "com.nateparrott.nat.thread", for: .autosaveAsOperation)
    }
}
