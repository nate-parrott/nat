import SwiftUI

struct WorktreeFooter: View {
    @Environment(\.document) private var document
    
    var body: some View {
        if document.store.model.isWorktreeFromOriginalFolder != nil {
            VStack(spacing: 8) {
                Text("Making changes in a worktree on branch `\(document.store.model.worktreeBranch ?? "")`")
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    Button("Review and Merge") {
                        NSWorkspace.shared.open(document.store.model.isWorktreeFromOriginalFolder!)
                    }
                    
                    Button("View in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: document.store.model.folder?.path() ?? "")
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.purple)
        }
    }
}