import SwiftUI

struct DocsBrowser: View {
    let files: [URL]
    @State private var selectedFile: URL?
    @State private var fileSaver: DebouncedFileSaver?
    
    var body: some View {
        HSplitView {
            DocsList(files: files, selectedFile: $selectedFile)
            
            if let selectedFile = selectedFile, let fileSaver = fileSaver {
                DocsEditor(fileSaver: fileSaver)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Select a file to edit")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.secondary)
            }
        }
        .onChange(of: selectedFile) { newFile in
            if let url = newFile {
                fileSaver = DebouncedFileSaver(fileURL: url)
            } else {
                fileSaver = nil
            }
        }
    }
}
