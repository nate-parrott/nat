import SwiftUI

struct ChatEmptyState: View {
    @Binding var wantsWorktree: Bool
    @Environment(\.document) private var document

    var body: some View {
        WithSnapshotMain(store: document.store, snapshot: { $0.thread.steps.isEmpty }) { empty in
            if empty {
                AgentSettings(wantsWorktree: $wantsWorktree)
                    .frame(maxWidth: 500)
                .padding()
            }
        }
    }
}


private struct AgentSettings: View {
    @Binding var wantsWorktree: Bool
    @Environment(\.document) private var document
    @State private var folderURL: URL?
    @State private var pickingFolder = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        let tintColor: Color = folderURL == nil ? Color.red : Color.blue
        
        VStack(alignment: .leading, spacing: 0) {
            selectFolderRow
            Divider()
//            tintColor.frame(height: 1).opacity(0.3)
            worktreeRow
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(folderURL == nil ? Color.red : Color.blue)
        .background {
            shape
                .fill(tintColor)
                .brightness(colorScheme == .dark ? 0 : -0.2)
                .opacity(colorScheme == .dark ? 0.1 : 0.07)
        }
        .overlay {
            shape.stroke(tintColor).opacity(0.3)
        }
        .onReceive(document.store.publisher.map(\.folder).removeDuplicates(), perform: { self.folderURL = $0 })
    }
    
    var selectFolderRow: some View {
        HStack {
            if let folderURL {
                Image(systemName: "folder")
                Text("\(folderURL.lastPathComponent)").bold()
                Spacer()
                Button(action: { pickingFolder = true }) {
                    Text("Change...")
                }
            } else {
                Group {
                    Image(systemName: "folder.fill.badge.plus")
                    Text("First, pick a folder").bold()
                }
                .brightness(-0.2)
                Spacer()
                Button(action: { pickingFolder = true }) {
                    Text("Select Folder...")
                }
            }
        }
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.directory], onCompletion: { result in
            if let url = try? result.get() {
                document.store.model.folder = url
            }
        })
        .padding(12)
    }
    
    var worktreeRow: some View {
        HStack {
            Toggle("Use Worktree to make edits in a separate folder", isOn: $wantsWorktree)
            Spacer()
            PopoverHint {
                Text(markdown: "This uses `git worktree` to check out this code in a different folder and make edits to it. Pair this with Autopilot to let the agent do a bunch of work on your behalf. When done, you can use git to review the changes and merge them.")
            }
        }
            .onChange(of: wantsWorktree) { newValue in
                document.store.modify { state in
                    if state.thread.steps.isEmpty {
                        state.autorun = newValue
                    }
                }
            }
            .padding(12)
    }
}
