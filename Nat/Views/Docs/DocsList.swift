import SwiftUI

struct DocsList: View {
    let files: [URL]
    @Binding var selectedFile: URL?
    
    var body: some View {
        List(files, id: \.absoluteString) { url in
            Text(url.lastPathComponent)
                .foregroundColor(url == selectedFile ? .accentColor : .primary)
                .onTapGesture {
                    selectedFile = url
                }
        }
        .frame(minWidth: 150, maxWidth: 200)
    }
}