//
//  Document+AutoTitle.swift
//  Nat
//

import Foundation
import ChatToys

struct AutoTitleResponse: Codable {
    var title: String
}

extension Document {
    func generateAndApplyAutoTitle(firstMessage: String) async throws {
        // Only auto-title unsaved documents
        guard fileURL == nil else { return }
        
        // Get the first message
        let firstMessage = firstMessage.truncateMiddleWithEllipsis(chars: 1000)
        
        // Create prompt for title generation
        let prompt = """
        Generate a concise, descriptive title for this chat, based on the first message. The title should be:
        - Short (2-4 words)
        - Technical and specific
        - Focused on the main task/goal
        
        Examples:
        - Add Icons to Dialogs
        - Fix Thread Crash
        - MoveOperation Tests
        
        First message:
        <first-message>
        \(firstMessage)
        </first-message>
        
        Output ONLY a JSON object like:
        {
            "title": "The generated title"
        }
        """
        
        // Generate title
        let llm = try LLMs.quickModel()
        
        let title = try await llm.completeJSONObject(prompt: [LLMMessage(role: .user, content: prompt)], type: AutoTitleResponse.self).title
        
        // Use application support directory for auto-saved chats
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let chatsDir = appSupport.appendingPathComponent("AutoSavedChats")
        try? FileManager.default.createDirectory(at: chatsDir, withIntermediateDirectories: true, attributes: nil)
        let saveURL = chatsDir.appendingUniqueComponent(title.asPathComponent, extension: "nat")
        
        try await save(to: saveURL, ofType: "com.nateparrott.nat.thread", for: .autosaveAsOperation)
    }
}

// MARK: - String Path Component Sanitization
extension String {
    /// Sanitizes a string for use as a filename
    var asPathComponent: String {
        let allowsChars = CharacterSet.alphanumerics.union(.init(charactersIn: " _-,+"))
        return self
            .components(separatedBy: allowsChars.inverted)
            .joined()
    }
}

// MARK: - URL Path Helpers
extension URL {
    /// Returns a URL with an incrementing number suffix if needed to avoid conflicts
    func appendingUniqueComponent(_ component: String, extension ext: String? = nil) -> URL {
        let url = self
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
