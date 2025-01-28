import SwiftUI

struct DocsList: View {
    let files: [URL]
    let reloadFileList: () -> Void
    @Binding var selectedFile: URL?
    @Environment(\.document) private var doc

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(files, id: \.self, selection: $selectedFile) { url in
                Text(url.lastPathComponent)
                    .contextMenu {
                        Button(action: { wantsDelete(url) }) {
                            Text("Delete")
                        }
                    }
            }
            .listStyle(.sidebar)

            Divider()

            Button(action: newFile) {
                Label("New File", systemImage: "plus")
            }
            .padding()
        }
        .frame(minWidth: 150, maxWidth: 200)
    }

    func wantsDelete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        reloadFileList()
    }

    func newFile() {
        Task {
            guard let folderURL = doc.store.model.folder else { return }
            guard var title = await Alerts.showAppPrompt(title: "New Doc File", message: "Choose a filename:", textPlaceholder: "my_doc.md", submitTitle: "Create", cancelTitle: "Cancel")?.nilIfEmpty else {
                return
            }
            if (title as NSString).pathExtension == "" {
                title += ".markdown"
            }
            let url = folderURL.appendingPathComponent(title, isDirectory: false)
            try? "Your docs here".write(to: url, atomically: true, encoding: .utf8)
            reloadFileList()
            selectedFile = url
        }
    }
}
