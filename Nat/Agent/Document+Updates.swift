//
//  Document+Changes.swift
//  Nat
//
//  Created by Nate Parrott on 3/7/25.
//

import Foundation

extension Document {
    func fetchUpdates() async throws -> ContextItem? {
        // TODO: Doesnt work b/c we don't know to stop sending the status update
        return nil
//        let fileSnippets = getUniqueFileSnippetsFromThread()
//        
//        var changedFiles = [String]()
//        
//        // Check each file snippet to see if its content has changed
//        for (path, snippet) in fileSnippets {
//            do {
//                let currentHash = try computeCurrentFileHash(for: path)
//                
//                // Compare current hash with stored hash
//                if currentHash != snippet.fullContentHash {
//                    changedFiles.append(snippet.projectRelativePath)
//                }
//            } catch {
//                // File might have been deleted or moved
//                changedFiles.append(snippet.projectRelativePath + " (might have been deleted)")
//            }
//        }
//        
//        // Return update message if files have changed
//        if changedFiles.isEmpty {
//            return nil
//        }
//        let message = "The following files have changed since they were last referenced:\n" +
//                      changedFiles.joined(separator: "\n")
//        return ContextItem.proactiveContext(title: "Files Changed", content: message)
    }
    
    // Helper to get unique file snippets from the thread (most recent version of each)
    private func getUniqueFileSnippetsFromThread() -> [URL: FileSnippet] {
        var uniqueFileSnippets = [URL: FileSnippet]()
        
        // Process thread from oldest to newest to keep most recent snippets
        for step in store.model.thread.steps {
            let items = step.allContextItems
            
            // Filter out file snippets
            for item in items {
                if case .fileSnippet(let snippet) = item {
                    // Store/overwrite with the latest version of each file
                    uniqueFileSnippets[snippet.path] = snippet
                }
            }
        }
        
        return uniqueFileSnippets
    }
    
    // Helper to compute current hash of a file
    private func computeCurrentFileHash(for path: URL) throws -> String {
        let data = try Data(contentsOf: path)
        return data.sha256Hash
    }
}

// Extension to extract all context items from a TaggedLLMMessage
extension TaggedLLMMessage {
    var allContextItems: [ContextItem] {
        var items = self.content
        
        // Add items from function responses
        for response in self.functionResponses {
            items.append(contentsOf: response.content)
        }
        
        return items
    }
}

// Extension to extract all context items from a thread step
extension ThreadModel.Step {
    var allContextItems: [ContextItem] {
        var items = initialRequest.allContextItems
        
        // Add items from tool use loop
        for step in toolUseLoop {
            items.append(contentsOf: step.initialResponse.allContextItems)
            
            // Add computer responses
            for response in step.computerResponse {
                items.append(contentsOf: response.content)
            }
            
            // Add pseudo function responses if any
            if let pseudoResponses = step.psuedoFunctionResponse {
                items.append(contentsOf: pseudoResponses)
            }
        }
        
        // Add assistant message if exists
        if let assistantMessage = assistantMessageForUser {
            items.append(contentsOf: assistantMessage.allContextItems)
        }
        
        return items
    }
}
