import SwiftUI

class DetailCoordinator: ObservableObject {
    @Published var clickedCellId: String?
    @Published var implicitlyShownCellId: String? // on appear, if there is room for a split view
}

struct SideDetailPresenter: View {
    var cellModels: [MessageCellModel]
    
    @EnvironmentObject private var detail: DetailCoordinator
    
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Group {
            if let clickedCellId = detail.clickedCellId ?? detail.implicitlyShownCellId, let cell = cellModels.first(where: { $0.id == clickedCellId }), let view = cell.detailView() {
                view
                    .background(.thickMaterial)
                    .clipShape(shape)
                    .overlay {
                        shape.stroke(Color.primary.opacity(0.1))
                    }
                    .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 8)
            } else {
                shape.fill(Color.secondary).opacity(0.1)
            }
        }
    }
}

struct ModalDetailPresenter: View {
    var cellModels: [MessageCellModel]
    
    @EnvironmentObject private var detail: DetailCoordinator
    
    var body: some View {
        ZStack {
            Color.black.opacity(detail.clickedCellId != nil ? 0.7 : 0)
                .onTapGesture {
                    detail.clickedCellId = nil
                    detail.implicitlyShownCellId = nil
                }
            
            if let clickedCellId = detail.clickedCellId, let cell = cellModels.first(where: { $0.id == clickedCellId }), let view = cell.detailView() {
                view
                    .background(.thickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .transition(.opacity.combined(with: .scale(0.5)))
                    .padding(50)
            }
        }
        .animation(.niceDefault(duration: 0.3), value: detail.clickedCellId != nil)
    }
}

extension MessageCellModel {
    func detailView() -> AnyView? {
        switch content {
        case .userMessage, .assistantMessage: return nil
        case .logs(let logsCluster):
            for log in logsCluster {
                switch log {
                case .readFile(let url):
                    return FileContentView(url: url).asAny
                case .grepped, .edits, .webSearch, .deletedFile, .codeSearch, .usingEditCleanupModel, .listedFiles, .tokenUsage, .effort, .toolWarning, .toolError, .readUrls: ()
                case .terminal:
                    return TerminalPreview().asAny
                }
            }
            return nil
        case .codeEdit(let codeEdit):
            return CodeEditView(edit: codeEdit).asAny
        case .error:
            return nil
        }
    }
}

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
    
//    @State private var height: CGFloat?
    @State private var size: CGSize?
    
    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 12) {
                content()
//                Spacer().frame(height: (height ?? 200 - 100))
            }
            .fixedSize()
            .frame(minWidth: size?.width, minHeight: size?.height, alignment: .topLeading)
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
//        .measureSize { self.height = $0.height }
        .measureSize { self.size = $0 }
    }
}
