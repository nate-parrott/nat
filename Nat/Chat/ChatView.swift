import ChatToys
import SwiftUI

struct ChatView: View {
//    @State private var messages: [LLMMessage] = []
    @State private var text = ""
    @State private var imageAttachment: ChatUINSImage? = nil

    @Environment(\.document) private var document
    @State private var typing = false
    @State private var messageCellModels = [MessageCellModel]()

    var body: some View {
        VStack(spacing: 0) {
            ChatThreadView(
                messages: messageCellModels,
                id: { cell, idx in cell.id },
                messageView: { message in
                    MessageCell(model: message)
//                    TextMessageBubble(Text(message.displayText), isFromUser: message.role == .user)
                },
                typingIndicator: typing,
                headerView: AnyView(AgentSettings())
            )
            Divider()
            ChatInputView_Multimodal(
                placeholder: "Message",
                text: $text,
                imageAttachment: $imageAttachment,
                sendAction: sendMessage
            )
        }
        .onReceive(document.store.publisher.map(\.thread.isTyping).removeDuplicates(), perform: { self.typing = $0 })
        .onReceive(document.store.publisher.map(\.thread.cellModels).removeDuplicates(), perform: { self.messageCellModels = $0 })
        .contextMenu {
            Button(action: clear) {
                Text("Clear")
            }
        }
    }

    private func clear() {
//        messages = []
        document.store.modify { state in
            state.thread = .init()
        }
        imageAttachment = nil
    }

    private func sendMessage() {
        let text = self.text
        self.text = ""

        var msg = LLMMessage(role: .user, content: text)
        if let imageAttachment {
            try! msg.add(image: imageAttachment, detail: .low)
            self.imageAttachment = nil
        }
        let folderURL = document.store.model.folder

        Task {
            do {
                try await document.send(message: msg, llm: LLMs.smartAgentModel(), tools: [FileReaderTool(), FileEditorTool(), CodeSearchTool(), FileTreeTool()], folderURL: folderURL)
            } catch {
                // Do nothing (We already handle it)
            }
        }
    }
}

struct ChatInputView_Multimodal: View {
    public let placeholder: String
    @Binding public var text: String
    @Binding var imageAttachment: ChatUINSImage?
    public let sendAction: () -> Void

    @State private var filePickerOpen = false

    public var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)

            Button(action: toggleImage) {
                HStack {
                    if imageAttachment != nil {
                        Text("Image attached")
                    }

                    Image(systemName: imageAttachment != nil ? "photo.fill" : "photo")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 20))
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: sendAction) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 30))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(text.isEmpty)
        }
        .fileImporter(isPresented: $filePickerOpen,
                        allowedContentTypes: [.image]) { result in
            guard case let .success(url) = result else { return }
            guard let image = ChatUINSImage(contentsOf: url) else { return }
            imageAttachment = image
          }
        .onSubmit {
            if !text.isEmpty {
                sendAction()
            }
        }
        .padding(10)
    }

    private func toggleImage() {
        if imageAttachment != nil {
            imageAttachment = nil
            return
        }
        filePickerOpen = true
    }
}

