import ChatToys
import SwiftUI

struct ChatView: View {
//    @State private var imageAttachment: ChatUINSImage? = nil
    
    @Environment(\.document) private var document
    @State private var status = AgentStatus.none
    @State private var messageCellModels = [MessageCellModel]()
    @State private var debug = false
    @State private var size: CGSize?
    @StateObject private var detailCoord = DetailCoordinator()

    var body: some View {
        let canShowSplitDetail = (size?.width ?? 100) >= 850
        let splitPaneWidth = (size?.width ?? 100) * 0.5
        ZStack {
            if debug {
                DebugThreadView()
            } else {
                VStack(spacing: 0) {
                    ScrollToBottomThreadView(data: messageCellModels) { message in
                        if canShowSplitDetail {
                            MessageCell(model: message)
                                .padding(.horizontal)
                                .frame(width: splitPaneWidth)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            MessageCell(model: message)
                                .padding(.horizontal)
                                .frame(maxWidth: 800, alignment: .center)
                        }
                    }
                    .overlay {
                        ChatEmptyState()
                    }
                    ChatInput(maxHeight: inputMaxHeight, send: sendMessage(text:attachments:), onStop: stopAgent)
                }
                .overlay(alignment: .bottom) {
                    if status == .running {
                        Shimmer()
                    }
                }
                .overlay {
                    if canShowSplitDetail {
                        SideDetailPresenter(cellModels: messageCellModels)
                            .frame(width: splitPaneWidth)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        ModalDetailPresenter(cellModels: messageCellModels)
                    }
                }
                .overlay {
                    if status == .running {
                        ToolModalPresenter()
                    }
                }
            }
        }
        .environmentObject(detailCoord)
        .onReceive(document.store.publisher.map(\.thread.status).removeDuplicates(), perform: { self.status = $0 })
        .onReceive(document.store.publisher.map(\.thread.cellModels).removeDuplicates(), perform: { self.messageCellModels = $0 })
        .contextMenu {
            Button(action: clear) {
                Text("Clear")
            }
            Button(action: { debug.toggle() }) {
                Text("Debug")
            }
        }
        .measureSize { self.size = $0 }
    }

    private var inputMaxHeight: CGFloat? {
        size != nil ? max(60, size!.height - 100) : nil
    }

    private func clear() {
        document.stop()
        document.store.modify { state in
            state.thread = .init(cancelCount: state.thread.cancelCount + 1)
            state.terminalVisible = false
        }
        document.terminal = nil
    }
    
    private func sendMessage(text: String, attachments: [ContextItem]) {
        let msg = TaggedLLMMessage(role: .user, content: [.text(text)] + attachments)
        let folderURL = document.store.model.folder
        let curFile = document.store.model.selectedFileInEditorRelativeToFolder

        document.stop()
 

        document.currentAgentTask = Task {
            guard let llm = try? LLMs.smartAgentModel() else {
                await Alerts.showAppAlert(title: "No API Key", message: "Add your API key in Nat → Settings")
                return
            }
            do {
                let tools: [Tool] = [
                    FileReaderTool(), FileEditorTool(), CodeSearchTool(), FileTreeTool(),
                    TerminalTool(), WebResearchTool(), DeleteFileTool(), GrepTool(),
                    BasicContextTool(document: document, currentFilenameFromXcode: curFile),
                ]
                try await document.send(message: msg, llm: llm, document: document, tools: tools, folderURL: folderURL, maxIterations: document.store.model.maxIterations)
            } catch {
                if Task.isCancelled { return }
                // Do nothing (We already handle it)
            }
            if !Task.isCancelled {
                document.currentAgentTask = nil
            }
        }
    }
    
    private func stopAgent() {
        document.stop()
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
                    .clipped()
            }
        }
        .onReceive(document.$toolModalToPresent, perform: { self.toolModal = $0 })
    }
}

struct ViewControllerPresenter: NSViewControllerRepresentable {
    var viewController: NSViewController

    func makeNSViewController(context: Context) -> NSViewController {
        viewController
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) { }
}

// A generic thread view that automatically scrolls to bottom when content changes
private struct ScrollToBottomThreadView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    var data: Data
    @ViewBuilder var content: (Data.Element) -> Content
    var spacing: CGFloat = 12

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: spacing) {
                    ForEach(data) { item in
                        content(item)
                            .transition(.blurReplace)

                    }
                }
                .padding(.bottom, 400)
                .padding(.vertical)
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.1), value: data.count)
            }
            .onChange(of: data.count) { oldCount, newCount in
                withAnimation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let last = data.last {
                            withAnimation(.niceDefault) {
                                proxy.scrollTo(last.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}
