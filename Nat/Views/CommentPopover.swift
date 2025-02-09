import SwiftUI

struct Comments: Equatable, Codable {
    var commentsByContext = [String: String]() // maps context strings (e.g. lines) to comments
}

struct CommentPopoverInlineView: View {
    var hovered: Bool
    @Binding var text: String // empty for no comment
    @State private var active = true
    
    var body: some View {
        Color.clear.frame(both: 18)
            .overlay {
                if hovered || text != "" || active {
                    FreeformButton(action: {
                        active = true
                    }) { status in
                        Image(systemName: text != "" ? "text.bubble.fill" : "plus.bubble.fill")
                            .frame(both: 18)
                            .font(.system(size: 14))
                            .foregroundStyle(text != "" ? Color.purple : Color.secondary)
                            .scaleEffect(status == .pressed ? 0.95 : (status == .hovered ? 1.05 : 1))
                            .animation(.easeInOut(duration: 0.1), value: status)
                            .help(text != "" ? text : "Add comment...")
                    }
                    .popover(isPresented: $active) {
                        PopoverCommentView(text: $text, presented: $active)
                    }
                }
            }
    }
}

private struct PopoverCommentView: View {
    @Binding var text: String
    @Binding var presented: Bool
    
    @State private var curText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            InputTextField(text: $curText, options: .init(placeholder: "Write comment...")) { event in
                // TODO: handle escape?
            }
            Divider()
            HStack {
                Button(action: { presented = false }) {
                    Text("Cancel")
                }
                if text != "" {
                    Button(action: { text = ""; presented = false }) {
                        Text("Delete")
                    }
                }
                Button(action: { text = curText; presented = false }) {
                    Text("Save")
                }
                .disabled(text == curText)
            }
        }
        .onAppear {
            self.curText = text
        }
        .frame(width: 400, height: 400)
    }
}
