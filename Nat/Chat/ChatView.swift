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
    @State private var wantsWorktree = false

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
                        ChatEmptyState(wantsWorktree: $wantsWorktree)
                    }
                    ChatInput(maxHeight: inputMaxHeight, send: { text, attachments in
                        Task {
                            await self.sendMessage(text: text, attachments: attachments)
                        }
                    }, onStop: stopAgent)
                    WorktreeFooter()
                }
                .overlay(alignment: .bottom) {
                    if status == .running {
                        Shimmer()
                    }
                }
                .overlay {
                    if canShowSplitDetail, !messageCellModels.isEmpty {
                        SideDetailPresenter(cellModels: messageCellModels)
                            .padding([.horizontal, .top])
                            .padding(.bottom, 60)
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
        document.clear()
    }
    
    @MainActor
    private func sendMessage(text: String, attachments: [ContextItem]) async {
        // If empty thread and worktree enabled, activate worktree
        if wantsWorktree, document.store.model.thread.steps.isEmpty, document.store.model.folder != nil {
            if !(await document.enterWorktreeModeOrShowError(initialPrompt: text)) {
                return
            }
            wantsWorktree = false
        }
        await document.send(text: text, attachments: attachments)
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
