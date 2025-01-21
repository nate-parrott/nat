import SwiftUI

struct ChatEmptyState: View {
    @Environment(\.document) private var document

    var body: some View {
        WithSnapshotMain(store: document.store, snapshot: { $0.thread.steps.isEmpty && $0.folder == nil }) { empty in
            if empty {
                VStack(spacing: 12) {
                    Text("Select a project folder to get started:")
                    Button(action: { document.pickFolder() }) {
                        Text("Choose Folder...")
                    }
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.secondary)
                        .opacity(0.1)
                }
            }
        }
    }
}
