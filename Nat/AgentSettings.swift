import SwiftUI

struct AgentSettings: View {
    @Environment(\.document) private var document
    @State private var folderURL: URL?
    @State private var pickingFolder = false

    var body: some View {
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
//            if let folderURL {
//                Image(systemName: "Folder")
//                Text("\(folderURL.lastPathComponent)")
//                Button(action: { pickingFolder = true }) {
//                    Text("Change...")
//                }
//            } else {
//                Button(action: { pickingFolder = true }) {
//                    Text("Select Folder...")
//                }
//            }
        }
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.directory], onCompletion: { result in
            if let url = try? result.get() {
                document.store.model.folder = url
            }
        })
        .padding()
        .frame(maxWidth: .infinity)
        .foregroundStyle(folderURL == nil ? Color.red : Color.blue)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(folderURL == nil ? Color.red : Color.blue)
                .brightness(-0.2)
                .opacity(0.07)
        }
        .onReceive(document.store.publisher.map(\.folder).removeDuplicates(), perform: { self.folderURL = $0 })
    }
}
