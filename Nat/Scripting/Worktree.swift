import Foundation

enum WorktreeCreationResult {
    case created(branch: String, folder: URL)
    case noDocDirectory
    case documentIsNotGitDir // Make sure the current folder is
    
}

extension Document {
    func tryEnterWorktreeMode(initialPrompt: String) async throws -> WorktreeCreationResult {
        guard let origBaseDir = store.model.isWorktreeFromOriginalFolder ?? store.model.folder else {
            return WorktreeCreationResult.noDocDirectory
        }
        // TODO: Check if git dir, then get current branch name
        // TODO: Create name
        // TODO: find valid worktree branch name and dir
        // TODO: create dir and run `git worktree` in the base dir to check it out
        // TODO: Then update document state (see Document.swift) to reflect our new base dir, and remember the old one as `isWorktreeFromOriginalFolder`
    }
    
    // Check if we can get a branch with this name and a sibling to basedir with this name. If not, then add an int and try again
    private func findValidWorktreeBranchNameAndDir(name: String, baseDir: URL) async throws -> (String, URL) {
        
    }
    
    private func nameBranchForWorktree(baseDir: URL, prompt: String) async throws -> String? {
        let allowedChars = "" // TODO: all letters, numbers, underscores only
        
        // Ask llm to name (use JSON response; search codebase for completeJSONObject)
    }
}
