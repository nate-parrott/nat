import Foundation
import ChatToys

enum WorktreeError: Error {
    case noDocDirectory
    case documentIsNotGitDir // Make sure the current folder is
}

extension Document {
    func enterWorktreeModeOrShowError(initialPrompt: String) async -> Bool {
        do {
            _ = try await tryEnterWorktreeMode(initialPrompt: initialPrompt)
            return true
        } catch WorktreeError.noDocDirectory {
            await Alerts.showAppAlert(title: "No Document Directory", 
                                    message: "Could not find a valid document directory.")
        } catch WorktreeError.documentIsNotGitDir {
            await Alerts.showAppAlert(title: "Not a Git Repository", 
                                    message: "The current directory is not a git repository.")
        } catch {
            await Alerts.showAppAlert(title: "Error Creating Worktree", 
                                    message: "An unexpected error occurred: \(error.localizedDescription)")
        }
        return false
    }
    
    func tryEnterWorktreeMode(initialPrompt: String) async throws -> (branch: String, folder: URL) {
        guard let origBaseDir = store.model.isWorktreeFromOriginalFolder ?? store.model.folder else {
            throw WorktreeError.noDocDirectory
        }
        // Check if git repo
        let gitDirCheck = Process()
        gitDirCheck.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitDirCheck.arguments = ["rev-parse", "--is-inside-work-tree"]
        gitDirCheck.currentDirectoryURL = origBaseDir
        
        do {
            try gitDirCheck.run()
            gitDirCheck.waitUntilExit()
            guard gitDirCheck.terminationStatus == 0 else {
                throw WorktreeError.documentIsNotGitDir
            }
        } catch {
            throw WorktreeError.documentIsNotGitDir
        }
        
        // Get unique branch name based on prompt
        guard let baseBranchName = try await nameBranchForWorktree(baseDir: origBaseDir, prompt: initialPrompt) else {
            throw WorktreeError.documentIsNotGitDir
        }
        
        // Find valid branch and directory names
        let (branchName, newDir) = try await findValidWorktreeBranchNameAndDir(name: baseBranchName, baseDir: origBaseDir)
        
        // Create worktree
        try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)
        
        let worktreeProcess = Process()
        worktreeProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        worktreeProcess.arguments = ["worktree", "add", "-b", branchName, newDir.path()]
        worktreeProcess.currentDirectoryURL = origBaseDir
        
        try worktreeProcess.run()
        worktreeProcess.waitUntilExit()
        
        guard worktreeProcess.terminationStatus == 0 else {
            try? FileManager.default.removeItem(at: newDir)
            throw WorktreeError.documentIsNotGitDir
        }
        
        // Update document state
        store.model.isWorktreeFromOriginalFolder = origBaseDir
        store.model.worktreeBranch = branchName
        store.model.folder = newDir
        
        return (branchName, newDir)
    }
    
    // Check if we can get a branch with this name and a sibling to basedir with this name. If not, then add an int and try again
    private func findValidWorktreeBranchNameAndDir(name: String, baseDir: URL) async throws -> (String, URL) {
        let baseName = name.lowercased()
        var suffix = 0
        let projectName = baseDir.lastPathComponent
        
        while true {
            let branchName = suffix == 0 ? baseName : "\(baseName)_\(suffix)"
            let dirName = suffix == 0 ? "\(projectName)_\(name)" : "\(projectName)_\(name)_\(suffix)"
            let potentialDir = baseDir.deletingLastPathComponent().appendingPathComponent(dirName)
            
            // Check if branch exists
            let branchCheckProcess = Process()
            branchCheckProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            branchCheckProcess.arguments = ["show-ref", "--verify", "--quiet", "refs/heads/\(branchName)"]
            branchCheckProcess.currentDirectoryURL = baseDir
            
            do {
                try branchCheckProcess.run()
                branchCheckProcess.waitUntilExit()
                
                // If branch doesn't exist (non-zero exit) and directory doesn't exist, we found a valid combo
                if branchCheckProcess.terminationStatus != 0 && !FileManager.default.fileExists(atPath: potentialDir.path) {
                    return (branchName, potentialDir)
                }
            } catch {
                // If git command fails, likely not a git repo
                throw WorktreeError.documentIsNotGitDir
            }
            
            suffix += 1
        }
    }
    
    private func nameBranchForWorktree(baseDir: URL, prompt: String) async throws -> String? {
        let allowedChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        
        // Create branch name format for LLM
        struct BranchNameResponse: Codable {
            let name: String
        }
        
        let llm = try LLMs.quickModel()
        let messages = [
            LLMMessage(role: .system, content: """
            Create a git branch name based on the given prompt.
            - Use only letters, numbers, and underscores 
            - Keep it under 50 chars
            - Make it descriptive but concise
            """),
            LLMMessage(role: .user, content: prompt)
        ]
        
        let response = try await llm.completeJSONObject(prompt: messages, type: BranchNameResponse.self)
        
        // Ensure the branch name only contains allowed chars
        let cleaned = response.name.components(separatedBy: allowedChars.inverted).joined()
        return cleaned.isEmpty ? nil : cleaned
    }
}
