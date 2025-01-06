import ChatToys
import SwiftUI

struct ChatView: View {
    @State private var messages: [LLMMessage] = []
    @State private var text = ""
    @State private var botIsTyping = false
    @State private var imageAttachment: ChatUINSImage? = nil

    var body: some View {
        VStack(spacing: 0) {
            ChatThreadView(
                messages: messages,
                id: {_, index in index },
                messageView: { message in
                    TextMessageBubble(Text(message.displayText), isFromUser: message.role == .user)
                },
                typingIndicator: botIsTyping
            )
            Divider()
            ChatInputView_Multimodal(
                placeholder: "Message",
                text: $text,
                imageAttachment: $imageAttachment,
                sendAction: sendMessage
            )
        }
        .contextMenu {
            Button(action: clear) {
                Text("Clear")
            }
        }
    }

    private func clear() {
        messages = []
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
        messages.append(msg)

        botIsTyping = true

        Task { [messages] in
            do {
                let llm = try LLMs.quickModel()
//                try await self.messages.append(llm.complete(prompt: Array(messages.suffix(7))))
//                self.botIsTyping = false
                var hasAppended = false
                for try await partial in llm.completeStreaming(prompt: Array(messages.suffix(7)), functions: []) {
                    if hasAppended {
                        self.messages.removeLast()
                    }
                    self.messages.append(partial)
                    hasAppended = true
                    self.botIsTyping = false
                }
            } catch {
                let text = "Error: \(error)"
                self.messages.append(.init(role: .system, content: text))
                self.botIsTyping = false
            }
        }
    }
}

extension LLMMessage {
    var displayText: String {
        var parts = [content]
        if images.count > 0 {
            parts.append("[\(images.count) images]")
        }
        return parts.joined(separator: " ")
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

