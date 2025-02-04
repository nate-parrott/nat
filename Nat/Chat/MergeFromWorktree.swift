import SwiftUI

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
            // Get initial diff on appear
            await loadDiff()
            isFeedbackFocused = true
        }
    }
    
    @MainActor func commit() async {
        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        addProcess.arguments = ["add", "."]
        addProcess.currentDirectoryURL = worktreeDir
        
        do {
            try addProcess.run()
            addProcess.waitUntilExit()
            
            if addProcess.terminationStatus == 0 {
                let commitProcess = Process()
                commitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                commitProcess.arguments = ["commit", "-m", "Auto commit pending changes"]
                commitProcess.currentDirectoryURL = worktreeDir
                
                try commitProcess.run()
                commitProcess.waitUntilExit()
            }
        } catch {
            errorMessage = "Failed to commit changes: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    private func loadDiff() async {
        await commit()
        
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["diff", "--no-pager", "HEAD"]
        process.currentDirectoryURL = worktreeDir
        process.standardOutput = pipe
        
        do {
            try process.run()
            if let data = try pipe.fileHandleForReading.readToEnd(),
               let output = String(data: data, encoding: .utf8) {
                diffText = output
            }
            process.waitUntilExit()
        } catch {
            errorMessage = "Failed to get diff: \(error.localizedDescription)"
        }
    }
    
    private func tryMerge() {
        // First check if there are uncommitted changes in main repo
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        checkProcess.arguments = ["diff", "--quiet"]
        checkProcess.currentDirectoryURL = origBaseDir
        
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            
            if checkProcess.terminationStatus != 0 {
                errorMessage = "Cannot merge: Original repository has uncommitted changes"
                return
            }
            
            // Now try the actual merge
            let mergeProcess = Process()
            mergeProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            mergeProcess.arguments = ["merge", "--no-pager", "--ff-only", "HEAD"]
            mergeProcess.currentDirectoryURL = origBaseDir
            
            try mergeProcess.run()
            mergeProcess.waitUntilExit()
            
            if mergeProcess.terminationStatus == 0 {
                // Success - send feedback if any
                if !feedback.isEmpty {
                    // TODO: Send FB
                }
                dismiss()
            } else {
                errorMessage = "Merge failed. Ensure you have no conflicts."
            }
        } catch {
            errorMessage = "Failed to merge: \(error.localizedDescription)"
        }
    }
}
