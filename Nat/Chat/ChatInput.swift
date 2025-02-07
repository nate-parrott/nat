import SwiftUI

struct ChatAttachment: Identifiable, Equatable {
    var id: String
    var contextItem: ContextItem
}

struct ChatInput: View {
    var maxHeight: CGFloat?
    var send: (String, [ContextItem]) -> Void
    var onStop: () -> Void
    @Environment(\.document) private var document
    
    @State private var text = ""
    @State private var focusDate: Date?
    @State private var textFieldSize: CGSize = .zero
    @State private var currentFileOpenInXcode: String?
    @State private var folderName: String?
    @State private var attachments: [ChatAttachment] = []
    @State private var status = AgentStatus.none
    @State private var autorun = false

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
                .frame(height: min(maxHeight ?? 999, max(textFieldSize.height, 60)))

                buttons
            }
            
            if !attachments.isEmpty {
                Divider()
                attachmentsView
            }
        }
        .overlay(alignment: .top) {
            if textFieldSize.height > 100 {
                Divider()
            }
        }
        .onAppear {
            focusDate = Date()
        }
        .onChange(of: text, perform: { newValue in
            if newValue != "" { document.pause() }
        })
        .background {
            if textFieldSize.height > 100 {
                Color.clear.background(.thinMaterial)
            }
        }
        .onReceive(document.store.publisher.map(\.selectedFileInEditorRelativeToFolder).removeDuplicates(), perform: { self.currentFileOpenInXcode = $0 })
        .onReceive(document.store.publisher.map(\.folder?.lastPathComponent).removeDuplicates(), perform: { self.folderName = $0 })
        .onReceive(document.store.publisher.map(\.autorun).removeDuplicates(), perform: { self.autorun = $0 })
    }

    @ViewBuilder var buttons: some View {
        HStack(spacing: 0) {
            Button(action: pickFile) {
                Image(systemName: "rectangle.dashed.and.paperclip")
                    .help(Text("Attach File"))
            }
            .buttonStyle(InputGlyphButtonStyle(color: .secondary, small: true))

            Button(action: { document.store.model.autorun.toggle() }) {
                Image(systemName: autorun ? "figure.run.circle.fill" : "figure.run.circle")
                    .help(Text(autorun ? "Autopilot is on; edits and terminal commands will run automatically." : "Autopilot is off; edits and terminal commands will prompt you."))
            }
            .buttonStyle(InputGlyphButtonStyle(color: .secondary, small: true))

            
            Group {
                if status == .running {
                    PlayPauseButton(icon: "pause.circle.fill", label: "Pause", action: { document.pause() })
                } else {
                    PlayPauseButton(icon: "play.circle.fill", label: "Start", action: { sendOrResume() })
                        .disabled(text.isEmpty && status == .none)
                }
            }
        }
        .frame(height: 60)
        .padding(.trailing)
        .onReceive(document.store.publisher.map(\.thread.status).removeDuplicates(), perform: { self.status = $0 })
    }

    private var textFieldOptions: InputTextFieldOptions {
        return .init(
            placeholder: placeholderText,
            font: .systemFont(ofSize: 14),
            insets: .init(width: 12, height: 21),
            requireCmdEnter: true,
            wantsUpDownArrowEvents: false
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
        switch event {
        case .key(.enter):
            sendOrResume()
        case .paste(let text):
            attachments.append(ChatAttachment(id: UUID().description, contextItem: .largePaste(text)))
        default:
            break
        }
    }
    
    private func sendOrResume() {
        if text != "" || attachments.count > 0 {
            let text = self.text
            let attachmentItems = self.attachments.map(\.contextItem)
            self.text = ""
            self.attachments = []
            send(text, attachmentItems)
        } else if status == .paused {
            document.unpause()
        }
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
                    attachments.append(ChatAttachment(id: UUID().description, contextItem: item))
                }
            }
        }
    }
    
    private var attachmentsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentPill(item: attachment.contextItem, onRemove: { attachments.removeAll(where: { $0.id == attachment.id }) })
                }
            }
            .padding(12)
        }
    }
}

private struct PlayPauseButton: View {
    var icon: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .help(Text(label))
        }
        .buttonStyle(InputGlyphButtonStyle(color: .accentColor, small: false))
    }
}

private struct InputGlyphButtonStyle: ButtonStyle {
    var color: Color
    var small: Bool
    @State private var hovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color)
            .font(.system(size: small ? 19 : 22))
            .frame(width: 40, height: 40)
            .scaleEffect(configuration.isPressed ? 0.9 : hovered ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: hovered)
            .onHover { hovered = $0 }
    }
}
