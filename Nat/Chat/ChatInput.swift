import SwiftUI

struct ChatInput: View {
    var send: (String) -> Void
    var onStop: () -> Void  // New callback for stop action
    @Environment(\.document) private var document
    
    @State private var text = ""
    @State private var focusDate: Date?
    @State private var textFieldSize: CGSize = .zero
    
    private var isTyping: Bool {
        document.store.model.thread.isTyping
    }
    
    var body: some View {
        HStack(alignment: .bottom) {
            InputTextField(
                text: $text,
                options: textFieldOptions,
                focusDate: focusDate,
                onEvent: textFieldEvent(_:),
                contentSize: $textFieldSize
            )
            .frame(height: max(textFieldSize.height, 60))
            
            if isTyping {
                // Show stop button when agent is typing
                Button(action: onStop) {
                    Image(systemName: "stop.circle.fill")
                        .help(Text("Stop Response"))
                        .foregroundColor(.red)
                        .font(.system(size: 30))
                        .padding(12)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Show send button when not typing
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .help(Text("Send Message"))
                        .foregroundColor(.accentColor)
                        .font(.system(size: 30))
                        .padding(12)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(text.isEmpty)
            }
        }
        .onAppear {
            focusDate = Date()
        }
    }
    
    private var textFieldOptions: InputTextFieldOptions {
        .init(
            placeholder: "Add a settings screen...", 
            font: .systemFont(ofSize: 14),
            insets: .init(width: 12, height: 21)
        )
    }
    
    private func textFieldEvent(_ event: TextFieldEvent) -> Void {
        if case .key(.enter) = event, text != "" {
            submit()
        }
    }
    
    private func submit() {
        let text = self.text
        self.text = ""
        send(text)
    }
}
