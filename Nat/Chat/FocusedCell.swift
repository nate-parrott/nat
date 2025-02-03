//
//  Focused.swift
//  Nat
//
//  Created by Nate Parrott on 2/2/25.
//
import SwiftUI

class CellFocusCoordinator: ObservableObject {
    @Published var focusedId: String?
}

struct FocusableCell: ViewModifier {
    var id: String
    @Binding var focused: Bool
    @EnvironmentObject private var coord: CellFocusCoordinator
    
    func body(content: Content) -> some View {
        content
            .onHover {
                if $0 {
                    coord.focusedId = id
                }
            }
            .onAppearOrChange(of: coord.focusedId == id) {
                self.focused = $0
            }
            .onAppear {
                coord.focusedId = id
            }
    }
}

struct FocusedCellDetailOverlay: View {
    var messageCellModels: [MessageCellModel]
    @EnvironmentObject private var coord: CellFocusCoordinator
    
    var body: some View {
        if let focusedId = coord.focusedId, let msg = messageCellModels.first(where: { $0.id == focusedId }) {
            HoverToRevealOverlay {
                FocusedCellContent(cell: msg)
            }
        }
    }
}

private struct HoverToRevealOverlay<C: View>: View {
    @ViewBuilder var content: () -> C
    
//    @State private var hoveredMain = false
    @State private var hoveredContent = false
    var overhang: CGFloat = 20
    var modalInset: CGFloat = 50
    
    var body: some View {
        let show = hoveredContent
        let shape = RoundedRectangle(cornerRadius: 6)
        GeometryReader { geo in
            let size = CGSize(width: max(geo.size.width - modalInset * 2, 100), height: max(geo.size.height - modalInset * 2, 100))
            
            ZStack(alignment: .topLeading) {
                Color.black.opacity(show ? 0.6 : 0)
                    .animation(.snappy, value: show)
                
                content()
                    .frame(width: size.width, height: size.height)
                    .background(.thickMaterial)
                    .clipShape(shape)
                    .overlay {
                        shape.strokeBorder(Color.primary).opacity(0.1)
                    }
                    .rotationEffect(.degrees(show ? 0 : 2))
                    .shadow(color: Color.black.opacity(0.1), radius: show ? 12 : 4, x: 0, y: 4)
                    .padding(.trailing, modalInset + 20) // extend hoverable area
                    .contentShape(.rect)
//                    .border(.red)
                    .onHover(perform: { self.hoveredContent = $0 })
                    .padding(.vertical, modalInset)
                    .padding(.leading, show ? modalInset : (geo.size.width - overhang))
                    .animation(.snappy, value: show)
            }
        }
    }
}

extension UserVisibleLog {
    var hasFocusDetail: Bool {
        switch self {
        case .readFile, .terminal:
            return true
        case .grepped, .edits, .webSearch, .deletedFile, .codeSearch, .usingEditCleanupModel, .listedFiles, .tokenUsage, .effort, .toolWarning, .toolError:
            return false
        }
    }
}

private struct FocusedCellContent: View {
    var cell: MessageCellModel
    
    var body: some View {
        switch cell.content {
        case .userMessage, .assistantMessage: EmptyView()
        case .toolLog(let userVisibleLog):
            switch userVisibleLog {
            case .readFile(let url):
                FileContentView(url: url)
            case .grepped, .edits, .webSearch, .deletedFile, .codeSearch, .usingEditCleanupModel, .listedFiles, .tokenUsage, .effort, .toolWarning, .toolError: EmptyView()
            case .terminal:
                TerminalPreview()
            }
        case .codeEdit(let codeEdit):
            CodeEditView(edit: codeEdit)
        case .error: EmptyView()
        }
    }
}

#Preview {
    Color.white.frame(both: 300)
        .overlay {
            HoverToRevealOverlay {
                Color.blue
            }
        }
}


