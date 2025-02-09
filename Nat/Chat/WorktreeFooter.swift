import SwiftUI

extension Document {
    @MainActor
    func deleteWorktree(at url: URL) async {
        let confirmed = await Alerts.showAppConfirmationDialog(
            title: "Delete Worktree?",
            message: "This will move the worktree folder to trash.",
            yesTitle: "Delete",
            noTitle: "Cancel"
        )
        
        if confirmed {
            // Move to trash
            let appleScript = "tell application \"Finder\" to delete (POSIX file \"" + url.path() + "\")"
            let script = NSAppleScript(source: appleScript)
            var error: NSDictionary?
            if script?.executeAndReturnError(&error) != nil {
                // Close document window
                NSApp.keyWindow?.close()
            }
        }
    }
}

struct WorktreeFooter: View {
    @Environment(\.document) private var document
    @State private var showingMergeSheet = false
    
    private struct WorktreeFooterSnapshot: Equatable {
        let origFolder: URL?
        let branch: String?
        let folder: URL?
        
        var isWorktree: Bool {
            origFolder != nil && branch != nil && folder != nil
        }
    }
    
    var body: some View {
        WithSnapshotMain(store: document.store, snapshot: { 
            WorktreeFooterSnapshot(
                origFolder: $0.isWorktreeFromOriginalFolder,
                branch: $0.worktreeBranch,
                folder: $0.folder
            )
        }) { snapshot in
            if snapshot.isWorktree, let branch = snapshot.branch {
                HStack(spacing: 12) {
                    Text("Worktree `\(branch)`")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack {
                        Button(action: {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: snapshot.folder?.path() ?? "")
                        }) {
                            Image(systemName: "folder")
                                .help("Reveal in Finder")
                        }
                        .buttonStyle(.plain)
                        
                        Button(role: .destructive, action: {
                            if let url = snapshot.folder {
                                Task {
                                    if await Alerts.showAppConfirmationDialog(title: "Delete worktree and close chat?", message: "This will erase your progress.", yesTitle: "Delete", noTitle: "Cancel") {
                                        await document.deleteWorktree(at: url)
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "trash")
                                .help(Text("Delete worktree and close chat"))
                        }
                        .buttonStyle(.plain)
                        
                        Button("Review & Merge") {
                            showingMergeSheet = true
                        }
                    }
                    .controlSize(.small)
                    .colorScheme(.dark)
                }
                .padding(6)
                .frame(maxWidth: .infinity)
                .background(Color.purple)
                .background(.thinMaterial)
                .sheet(isPresented: $showingMergeSheet) {
                    if let origFolder = snapshot.origFolder, let worktree = snapshot.folder, let branch = snapshot.branch {
                        MergeFromWorktreeView(branch: branch, origBaseDir: origFolder,
                                        worktreeDir: worktree)
                    }
                }
            }
        }
    }
}
