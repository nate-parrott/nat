import SwiftUI

struct DocsView: View {
    @Environment(\.document) private var document
    @State private var files: [URL]?
    
    var folder: URL? { document.store.model.folder }
    
    var docsFolder: URL? {
        folder?.appendingPathComponent("nat_docs")
    }
    
    func loadFiles() {
        guard let docsFolder = docsFolder else {
            files = nil
            return
        }
        
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: docsFolder,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension.lowercased() == "markdown" }
            files = urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            files = nil
        }
    }
    
    func createDocsFolder() {
        guard let docsFolder = docsFolder else { return }
        do {
            try FileManager.default.createDirectory(at: docsFolder, withIntermediateDirectories: true)
            let notesURL = docsFolder.appendingPathComponent("notes.markdown")
            try "Anything in notes.markdown will be passed as guidance to the agent automatically.".write(to: notesURL, atomically: true, encoding: .utf8)
            loadFiles()
        } catch {
            print("Error creating docs folder: \(error)")
        }
    }
    
    var body: some View {
        Group {
            if folder == nil {
                Text("Open a folder to use docs")
                    .foregroundColor(.secondary)
            } else if let files = files, !files.isEmpty {
                DocsBrowser(files: files, reloadFileList: loadFiles)
            } else {
                VStack {
                    Text("No docs folder found")
                        .foregroundColor(.secondary)
                    Button("Create docs folder") {
                        createDocsFolder()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onAppear {
            loadFiles()
        }
        .onChange(of: folder) { _ in
            loadFiles()
        }
    }
}
