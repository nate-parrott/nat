import ChatToys
import SwiftUI

struct ChatView: View {
    @State private var text = ""
    @State private var imageAttachment: ChatUINSImage? = nil
    
    @Environment(\.document) private var document
    @State private var typing = false
    @State private var messageCellModels = [MessageCellModel]()
    @State private var debug = false
    
    var body: some View {
        VStack(spacing: 0) {
            if debug {
                DebugThreadView()
            } else {
                ScrollToBottomThreadView(data: messageCellModels) { message in
                    MessageCell(model: message)
                        .frame(maxWidth: 800, alignment: .leading)
                }
                .overlay(alignment: .bottomTrailing) {
                    TerminalThumbnail()
                }
                .overlay {
                    ToolModalPresenter()
                }
            }
            Divider()
            ChatInput(send: sendMessage(text:), onStop: stopAgent)
        }
        .overlay(alignment: .bottom) {
            if typing {
                Shimmer()
            }
        }
        .onReceive(document.store.publisher.map(\.thread.isTyping).removeDuplicates(), perform: { self.typing = $0 })
        .onReceive(document.store.publisher.map(\.thread.cellModels).removeDuplicates(), perform: { self.messageCellModels = $0 })
        .contextMenu {
            Button(action: clear) {
                Text("Clear")
            }
            Button(action: { debug.toggle() }) {
                Text("Debug")
            }
        }
    }
    
    private func clear() {
        document.store.modify { state in
            state.thread = .init()
        }
        imageAttachment = nil
    }
    
    private func sendMessage(text: String) {
        var msg = TaggedLLMMessage(role: .user, content: [.text(text)])
        if let imageAttachment {
            try! msg.content.append(.image(imageAttachment.asLLMImage(detail: .high)))
            self.imageAttachment = nil
        }
        let folderURL = document.store.model.folder
        let curFile = document.store.model.selectedFileInEditorRelativeToFolder
        
        document.currentAgentTask?.cancel() // Cancel any existing task
        
        document.currentAgentTask = Task {
            do {
                let tools: [Tool] = [
                    FileReaderTool(), FileEditorTool(), CodeSearchTool(), FileTreeTool(),
                    TerminalTool(), WebResearchTool(), DeleteFileTool(), GrepTool(),
                    BasicContextTool(currentFilenameFromXcode: curFile)
                ]
                try await document.send(message: msg, llm: LLMs.smartAgentModel(), document: document, tools: tools, folderURL: folderURL)
            } catch {
                if Task.isCancelled { return }
                // Do nothing (We already handle it)
            }
            document.currentAgentTask = nil
        }
    }
    
    private func stopAgent() {
        // Cancel the current agent task
        document.currentAgentTask?.cancel()
        document.currentAgentTask = nil
        
        // Reset typing state
        document.store.modify { state in
            state.thread.isTyping = false
        }
    }
}

private struct ToolModalPresenter: View {
    @Environment(\.document) private var document
    @State private var toolModal: NSViewController? = nil

    var body: some View {
        ZStack {
            if let toolModal {
                ViewControllerPresenter(viewController: toolModal)
                    .background(.thickMaterial)
                    .id(ObjectIdentifier(toolModal))
            }
        }
        .onReceive(document.$toolModalToPresent, perform: { self.toolModal = $0 })
    }
}

private struct ViewControllerPresenter: NSViewControllerRepresentable {
    var viewController: NSViewController

    func makeNSViewController(context: Context) -> NSViewController {
        viewController
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) { }
}

// A generic thread view that automatically scrolls to bottom when content changes
private struct ScrollToBottomThreadView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    var data: Data
    var content: (Data.Element) -> Content
    var spacing: CGFloat = 12

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: spacing) {
                    ForEach(data) { item in
                        content(item)
                    }
                }
                .padding()
                .padding(.bottom, 400)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: data.count) { _ in
                withAnimation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        if let last = data.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}
