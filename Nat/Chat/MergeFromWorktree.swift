import SwiftUI

// Helper for git operations
private struct GitHelper {
    let execPath = "/usr/bin/git"
    
    struct GitError: Error {
        let message: String
    }
    
    @discardableResult static func runGit(args: [String], dir: URL, throwIfStatusNonzero: Bool) throws -> String? {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = dir
        process.standardOutput = pipe
        
        try process.run()
        let data = try pipe.fileHandleForReading.readToEnd()
        process.waitUntilExit()
        
        if throwIfStatusNonzero {
            guard process.terminationStatus == 0 else {
                throw GitError(message: "Git command failed: git \(args.joined(separator: " "))")
            }
        }
        
        return data.flatMap { String(data: $0, encoding: .utf8) }
    }
    
    static func getBaseHeadCommit(baseDir: URL) throws -> String {
        guard let output = try runGit(args: ["rev-parse", "HEAD"], dir: baseDir, throwIfStatusNonzero: true)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw GitError(message: "Could not get HEAD commit")
        }
        return output
    }
    
    static func commit(dir: URL, message: String) throws {
        try runGit(args: ["add", "."], dir: dir, throwIfStatusNonzero: true)
        try runGit(args: ["commit", "-m", message], dir: dir, throwIfStatusNonzero: false) // will be nonzero if nothing to commit
    }
    
    static func hasUncommittedChanges(dir: URL) throws -> Bool {
        do {
            try runGit(args: ["diff", "--quiet"], dir: dir, throwIfStatusNonzero: true)
            return false
        } catch {
            return true
        }
    }
    
    static func merge(dir: URL) throws {
        try runGit(args: ["merge", "--no-pager", "--ff-only", "HEAD"], dir: dir, throwIfStatusNonzero: true)
    }
}

struct MergeFromWorktreeView: View {
    @Environment(\.document) private var document
    @Environment(\.dismiss) private var dismiss
    @State private var feedback = ""
    @State private var diffText = ""
    @State private var errorMessage: String? = "Test error oeirh oerh ore ugebr ugbheui fbheu re u"
    @FocusState private var isFeedbackFocused: Bool
    
    let branch: String
    let origBaseDir: URL
    let worktreeDir: URL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Review Changes")
                .font(.headline)
                .padding(8)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DiffView(diff: Diff.from(before: [],
                                           after: diffText.components(separatedBy: "\n"),
                                           collapseSames: true))
                        .lineLimit(nil)
                        .font(.system(.body, design: .monospaced))
                }
            }
            
            Divider()
                        
//            TextField("Optional feedback for model...", text: $feedback, axis: .vertical)
//                .lineLimit(3)
//                .focused($isFeedbackFocused)
//                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                
                Button("Merge Changes") {
                    tryMerge()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .trailing)
            
            Text(markdown: "Run `git merge \(branch)` to merge manually")
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.1))
            
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red)
                    .multilineTextAlignment(.leading)
                    .font(.callout)
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
            // git --no-pager diff 353a1c3b5d22fd01b0ae5209d4ffb1149f17359d...HEAD
            if let diff = try GitHelper.runGit(args: ["--no-pager", "diff", baseHead + "...HEAD"], dir: worktreeDir, throwIfStatusNonzero: true) {
                diffText = diff
            }
        } catch {
            print("Failed to get diff: \(error)")
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
