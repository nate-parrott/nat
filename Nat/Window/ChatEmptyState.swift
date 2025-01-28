import SwiftUI

struct ChatEmptyState: View {
    @Environment(\.document) private var document

    var body: some View {
        WithSnapshotMain(store: document.store, snapshot: { $0.thread.steps.isEmpty }) { empty in
            if empty {
                AgentSettings()
                    .frame(maxWidth: 500)
                .padding()
            }
        }
    }
}
