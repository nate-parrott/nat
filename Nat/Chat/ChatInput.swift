import SwiftUI

struct ChatInput: View {
    var send: (String, [ContextItem]) -> Void
    var onStop: () -> Void
    @Environment(\.document) private var document
    
    @State private var text = ""
    @State private var focusDate: Date?
    @State private var textFieldSize: CGSize = .zero
    @State private var currentFileOpenInXcode: String?
    @State private var folderName: String?
    @State private var attachments: [ContextItem] = []

    private var isTyping: Bool {
        document.store.model.thread.isTyping
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                InputTextField(
                    text: $text,
                    options: textFieldOptions,
                    focusDate: focusDate,
                    onEvent: textFieldEvent(_:),
                    contentSize: $textFieldSize
                )
                .frame(height: max(textFieldSize.height, 60))

                buttons
            }
            
            if !attachments.isEmpty {
                Divider()
                attachmentsView
            }
        }
        .onAppear {
            focusDate = Date()
        }
        .onReceive(document.store.publisher.map(\.selectedFileInEditorRelativeToFolder).removeDuplicates(), perform: { self.currentFileOpenInXcode = $0 })
        .onReceive(document.store.publisher.map(\.folder?.lastPathComponent).removeDuplicates(), perform: { self.folderName = $0 })
    }

    @ViewBuilder var buttons: some View {
        HStack(spacing: 0) {
            Button(action: pickFile) {
                Image(systemName: "paperclip")
                    .help(Text("Attach File"))
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                    .frame(both: 40)
            }
            .buttonStyle(PlainButtonStyle())

            if isTyping {
                // Show stop button when agent is typing
                Button(action: onStop) {
                    Image(systemName: "stop.circle.fill")
                        .help(Text("Stop Response"))
                        .foregroundColor(.red)
                        .font(.system(size: 30))
                        .frame(both: 40)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Show send button when not typing
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .help(Text("Send Message"))
                        .foregroundColor(.accentColor)
                        .font(.system(size: 30))
                        .frame(both: 40)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(text.isEmpty)
            }
        }
        .frame(height: 60)
        .padding(.trailing)
    }

    private var textFieldOptions: InputTextFieldOptions {
        return .init(
            placeholder: placeholderText,
            font: .systemFont(ofSize: 14),
            insets: .init(width: 12, height: 21)
        )
    }

    private var placeholderText: String {
        if let folderName {
            if let currentFileOpenInXcode {
                let filename = (currentFileOpenInXcode as NSString).lastPathComponent
                return "What can I edit in \(filename) or \(folderName)?"
            }
            return "What can I edit in \(folderName)?"
        }
        return "What can I edit for you?"
    }

    private func textFieldEvent(_ event: TextFieldEvent) -> Void {
        if case .key(.enter) = event, text != "" {
            submit()
        }
    }
    
    private func submit() {
        let text = self.text
        let attachments = self.attachments
        self.text = ""
        self.attachments = []
        send(text, attachments)
    }
    
    @MainActor
    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        
        guard panel.runModal() == .OK else { return }
        Task { @MainActor in
            for url in panel.urls {
                if let item = try? await ContextItem.from(url: url, projectFolder: document.store.model.folder) {
                    attachments.append(item)
                }
            }
        }
    }
    
    private var attachmentsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEachUnidentifiable(items: Array(attachments.enumerated())) { item in
                    AttachmentPill(item: item.element, onRemove: { attachments.remove(at: item.offset) })
                }
            }
            .padding(12)
        }
//        .frame(height: attachments.isEmpty ? 0 : 32)
    }
}
