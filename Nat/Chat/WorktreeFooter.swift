import SwiftUI

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
                    
                    Button("Reveal") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: snapshot.folder?.path() ?? "")
                    }
                    .controlSize(.small)

                    
                    Button("Review & Merge") {
                        showingMergeSheet = true
                    }
                    .controlSize(.small)
                    .sheet(isPresented: $showingMergeSheet) {
                        if let origFolder = snapshot.origFolder {
                            MergeFromWorktree(origBaseDir: origFolder, 
                                            worktreeDir: snapshot.folder!)
                        }
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity)
                .background(Color.purple)
                .background(.thinMaterial)
            }
        }
    }
}
