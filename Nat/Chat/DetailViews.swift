import SwiftUI

struct CodeEditView: View {
    var edit: CodeEdit
        
    var body: some View {
        ScrollableCodeView {
            Text("Editing \(edit.url.lastPathComponent)")
            Divider()
            switch edit {
            case .replace(_, let lineRangeStart, let lineRangeLen, let lines):
                Text("Replacing lines \(lineRangeStart)-\(lineRangeStart + lineRangeLen)")
                    .opacity(0.5)
                Text(lines.joined(separator: "\n"))
                    .foregroundStyle(Color.newCodeGreen)
            case .write(_, let content):
                Text("Writing to file:")
                    .opacity(0.5)
                Text(content)
                    .foregroundStyle(Color.newCodeGreen)
            case .append(_, let content):
                Text("Appending:")
                    .opacity(0.5)
                Text(content)
                    .foregroundStyle(Color.newCodeGreen)
            case .findReplace(_, let find, let replace):
                Text("Replacing \(find.count) lines with:")
                    .opacity(0.5)
                Text(replace.joined(separator: "\n"))
                    .foregroundStyle(Color.newCodeGreen)
            }
        }
    }
}

struct FileContentView: View {
    var url: URL
    
    @State private var content: String?
    
    var body: some View {
        ScrollableCodeView {
            Text("Viewing latest copy of \(url.lastPathComponent)")
                .foregroundColor(.accentColor)
            Divider()
            Text(content ?? "")
        }
        .onAppearOrChange(of: url) { url in
            Task {
                let res: String? = await DispatchQueue.global().performAsync({
                    try? String(contentsOf: url)
                })
                self.content = res
            }
        }
    }
}

struct ScrollableCodeView<C: View>: View {
    @ViewBuilder var content: () -> C
    
    @State private var height: CGFloat?
    
    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 12) {
                content()
                Spacer().frame(height: (height ?? 200 - 100))
            }
            .fixedSize()
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .measureSize { self.height = $0.height }
    }
}
