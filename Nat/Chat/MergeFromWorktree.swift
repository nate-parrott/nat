import SwiftUI

// Helper for git operations
private struct GitHelper {
    let execPath = "/usr/bin/git"
    
    struct GitError: Error {
        let message: String
    }
    
    @discardableResult static func runGit(args: [String], dir: URL) throws -> String? {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = dir
        process.standardOutput = pipe
        
        try process.run()
        let data = try pipe.fileHandleForReading.readToEnd()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw GitError(message: "Git command failed")
        }
        
        return data.flatMap { String(data: $0, encoding: .utf8) }
    }
    
    static func getBaseHeadCommit(baseDir: URL) throws -> String {
        guard let output = try runGit(args: ["rev-parse", "HEAD"], dir: baseDir)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw GitError(message: "Could not get HEAD commit")
        }
        return output
    }
    
    static func commit(dir: URL, message: String) throws {
        try runGit(args: ["add", "."], dir: dir)
        try runGit(args: ["commit", "-m", message], dir: dir)
    }
    
    static func hasUncommittedChanges(dir: URL) throws -> Bool {
        do {
            try runGit(args: ["diff", "--quiet"], dir: dir)
            return false
        } catch {
            return true
        }
    }
    
    static func merge(dir: URL) throws {
        try runGit(args: ["merge", "--no-pager", "--ff-only", "HEAD"], dir: dir)
    }
}

struct MergeFromWorktree: View {
    @Environment(\.document) private var document
    @Environment(\.dismiss) private var dismiss
    @State private var feedback = ""
    @State private var diffText = ""
    @State private var errorMessage: String?
    @FocusState private var isFeedbackFocused: Bool
    
    let origBaseDir: URL
    let worktreeDir: URL
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Review Changes")
                .font(.headline)
            
            ScrollView {
                DiffView(diff: Diff.from(before: [], 
                                       after: diffText.components(separatedBy: "\n"), 
                                       collapseSames: true))
                    .lineLimit(nil)
                    .font(.system(.body, design: .monospaced))
            }
            .frame(height: 300)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            
            TextField("Optional feedback for model...", text: $feedback, axis: .vertical)
                .lineLimit(3)
                .focused($isFeedbackFocused)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                
                Button("Merge Changes") {
                    tryMerge()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
        .frame(width: 600)
        .task {
            await loadDiff()
            isFeedbackFocused = true
        }
    }
    
    @MainActor
    private func loadDiff() async {
        do {
            // First commit any pending changes
            try GitHelper.commit(dir: worktreeDir, message: "Auto commit pending changes")
            
            // Get base HEAD commit
            let baseHead = try GitHelper.getBaseHeadCommit(baseDir: origBaseDir)
            
            // Diff against base HEAD
            if let diff = try GitHelper.runGit(args: ["diff", "--no-pager", baseHead], dir: worktreeDir) {
                diffText = diff
            }
        } catch {
            errorMessage = "Failed to get diff: \(error.localizedDescription)"
        }
    }
    
    private func tryMerge() {
        do {
            // Check for uncommitted changes
            if try GitHelper.hasUncommittedChanges(dir: origBaseDir) {
                errorMessage = "Cannot merge: Original repository has uncommitted changes"
                return
            }
            
            // Try merge
            try GitHelper.merge(dir: origBaseDir)
            
            // Success - send feedback if any
            if !feedback.isEmpty {
                // TODO: Send FB
            }
            dismiss()
            
        } catch {
            errorMessage = "Failed to merge: \(error.localizedDescription)"
        }
    }
}
