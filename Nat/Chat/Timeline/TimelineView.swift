import SwiftUI

struct ChatTimelineView: View {
    var items: [TimelineItem]
    
    @State var currentItem: TimelineItem.ID?
    @State var hoveredItem: TimelineItem.ID?
    @State private var toolModal: NSViewController? = nil
    @Environment(\.document) private var document
    @State private var status: AgentStatus = .none
    
    var body: some View {
        VStack {
            if let itemId = hoveredItem ?? currentItem ?? items.last?.id, let item = items.first(where: { $0.id == itemId }) {
                ChatTimelinePage(item: item)
                    .id(itemId)
                    .transition(.opacity)
                    .animation(.niceDefault(duration: 0.12), value: currentItem)
            } else {
                Color.clear
            }
            
            TimelineSlider(items: items, currentItem: $currentItem, hoveredItem: $hoveredItem)
                .padding(.horizontal, 4)
                .onAppearOrChange(of: items.last?.id) {
                    if let id = $0, currentItem == nil {
                        currentItem = id
                    }
                }
        }
        .onReceive(document.$toolModalToPresent, perform: { self.toolModal = $0 })
        .onReceive(document.store.publisher.map(\.thread.status), perform: { self.status = $0 })
    }
    
    var effectiveTimelineItems: [TimelineItem] {
        var items = self.items
        if status == .running, let toolModal {
            items.append(.init(id: "toolModal", backdrop: .toolModal(toolModal), markerIcon: "exclamationmark.bubble.fill", messages: []))
        }
        return items
    }
}

private struct ChatTimelinePage: View {
    var item: TimelineItem
    @State private var height: CGFloat?
    @Environment(\.document) private var document
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        Group {
            if let bg = item.backdrop {
                Color.clear.overlay {
                    switch bg {
                    case .terminal:
                        WithSnapshotMain(store: document.store, snapshot: { $0.terminalVisible }) { vis in
                            if vis, let term = document.terminal {
                                ScriptableTerminalViewRepresentable(terminal: term)
                            } else {
                                Color.black
                                    .overlay {
                                        Text("No terminal running")
                                            .fontDesign(.monospaced)
                                            .foregroundStyle(.white)
                                            .opacity(0.4)
                                    }
                            }
                        } // TODO: fixed size for terminal?
                    case .viewFile(let url):
                        FileContentView(url: url)
                    case .editFile(let codeEdit):
                        CodeEditView(edit: codeEdit)
                    case .toolModal(let vc):
                        ViewControllerPresenter(viewController: vc)
                            .id(ObjectIdentifier(vc))
                    }
                }
                .overlay(alignment: .bottom) {
                    FeatheredOverlayScrollView(cells: item.messages)
                }
                .overlay(alignment: .bottom) {
                    Divider()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(item.messages) { msg in
                            MessageCell(model: msg, backdrop: false)
                                .transition(.blurReplace)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.bouncy, value: item.messages.count)
                }
            }
        }
//        .clipShape(shape)
//        .background {
//            shape
//                .fill(Color.white)
//                .shadow(color: Color.black, radius: 6, x: 0, y: 2)
//                .opacity(colorScheme == .light ? 0.1 : 0.05)
//        }
        .measureSize({ height = $0.height })
        .id(item.id)
//        .padding([.horizontal, .top], 12)
    }
}

private struct FeatheredOverlayScrollView: View {
    var cells: [MessageCellModel]
    
    var body: some View {
        GeometryReader { geo in
            let scrollHeight = min(geo.size.height, 300)
            let featherHeight: CGFloat = 20
            ExpandingScrollView(maxHeight: scrollHeight) {
                VStack(alignment: .leading) {
                    Spacer().frame(height: featherHeight)
                    ForEach(cells) { cell in
                        MessageCell(model: cell, backdrop: true, showCodeEditCards: false)
                            .transition(.blurReplace)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.bouncy, value: cells.count)
            }
            .mask {
                LinearGradient(colors: [Color.white.opacity(0), Color.white], startPoint: .init(x: 0, y: 0), endPoint: .init(x: 0, y: featherHeight / scrollHeight))
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
        }
    }
}


private struct TimelineSlider: View {
    var items: [TimelineItem]
    @Binding var currentItem: TimelineItem.ID?
    @Binding var hoveredItem: TimelineItem.ID?
    
    @State private var filledBarWidth: CGFloat?
    @State private var hoveredBarWidth: CGFloat?
    @State private var fullBarWidth: CGFloat?
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Group {
                    if let icon = item.markerIcon {
                        TimelinePill(iconSystemName: icon, selected: item.id == currentItem)
                            .brightness(item.id == hoveredItem ? -0.1 : 0)
                            .help(item.markerName ?? "Page")
                    } else {
                        Color.clear.frame(maxWidth: 32)
                    }
                }
                .frame(height: 32)
//                .foregroundStyle(item.id == currentItem ? Color.accentColor : (item.id == hoveredItem ? Color.primary : Color.secondary))
                .contentShape(Rectangle())
                .background {
                    ZStack {
                        if item.id == currentItem {
                            Color.clear.measureFrame(coordinateSpace: .named("Slider"), { self.filledBarWidth = $0.midX })
                        }
                        if item.id == hoveredItem {
                            Color.clear.measureFrame(coordinateSpace: .named("Slider"), { self.hoveredBarWidth = $0.midX })
                        }
                    }
                }
                .onHover { hovered in
                    if hovered {
                        hoveredItem = item.id
                    }
                }
                .onTapGesture {
                    currentItem = item.id
                }
            }
            
            Spacer().frame(width: 50)
        }
        .padding(.horizontal, -6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .measureSize({ self.fullBarWidth = $0.width })
        .background {
//            Capsule()
//                .frame(height: 4)
            if let fullBarWidth, let filledBarWidth {
                TimelineBar(progress: filledBarWidth / fullBarWidth, hoverProgress: hoveredItem != nil && hoveredBarWidth != nil ? (hoveredBarWidth! / fullBarWidth) : nil)
            }
        }
        .contentShape(.rect)
        .onHover {
            if !$0 {
                hoveredItem = nil
            }
        }
        .coordinateSpace(name: "Slider")
        .padding(.horizontal, 12)
    }
}

private struct TimelineBar: View {
    var progress: CGFloat
    var hoverProgress: CGFloat?
    
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .background(Color.primary.opacity(0.1))
                .overlay(alignment: .leading) {
                    Color.accentColor.frame(width: progress * geo.size.width)
                }
                .overlay(alignment: .leading) {
                    if let hoverProgress {
                        Color.white.opacity(0.2)
                            .frame(width: hoverProgress * geo.size.width)
                    }
                }
        }
        .clipShape(Capsule())
        .overlay {
            Capsule().strokeBorder(Color.primary.opacity(0.1))
        }
        .frame(height: 4)
    }
}

private struct TimelinePill: View {
    var iconSystemName: String
    var selected: Bool
    
    var body: some View {
        Image(systemName: iconSystemName)
            .font(.system(size: 12))
            .frame(both: 32)
            .foregroundStyle(selected ? Color.white : Color.accentColor)
            .background {
                Circle().fill(selected ? Color.accentColor : Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(4)
            }
    }
}
