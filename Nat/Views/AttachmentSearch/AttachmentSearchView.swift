import SwiftUI

struct AttachmentSearchModifier: ViewModifier {
    @Binding var presented: Bool
    @Binding var attachments: [ChatAttachment]
    
    func body(content: Content) -> some View {
        content
            .popover(isPresented: $presented) {
                AttachmentSearchView { items in
                    presented = false
                    attachments += items.map({ item in
                        ChatAttachment(id: UUID().uuidString, contextItem: item)
                    })
                }
                .frame(width: 300, height: 300)
            }
    }
}

struct AttachmentSearchView: View {
    let done: ([ContextItem]) -> Void
    @Environment(\.document) private var document
    @StateObject private var provider = AttachmentSearchProvider()
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var focusDate: Date?
    
    var body: some View {
        VStack(spacing: 0) {
            InputTextField(text: $searchText,
                           options: .init(placeholder: "Filter Files...", insets: CGSize(width: 12, height: 12), wantsUpDownArrowEvents: true),
                         focusDate: focusDate,
                         onEvent: handleTextFieldEvent)
                .background(.thickMaterial)
                .frame(height: 40)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEachUnidentifiableWithIndices(items: provider.results) { index, result in
                        AttachmentSearchCell(result: result, selected: index == selectedIndex)
                        .onTapGesture {
                            selectedIndex = index
                        }
                    }
                    
                    // idk why this doesnt work as an overlay
                    if searchText != "", provider.results.count == 0 {
                        Text("No Results")
                            .foregroundStyle(.tertiary)
                            .padding()
                    }

                }
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            focusDate = Date()
            provider.baseURL = document.store.model.folder
        }
        .onChange(of: document.store.model.folder) { folder in
            provider.baseURL = folder
        }
        .onChange(of: searchText) { newValue in
            provider.search(query: newValue)
            selectedIndex = 0
        }
    }
    
    private func handleTextFieldEvent(_ event: TextFieldEvent) {
        switch event {
        case .key(.upArrow):
            selectedIndex = max(0, selectedIndex - 1)
        case .key(.downArrow):
            selectedIndex = min(provider.results.count - 1, selectedIndex + 1)
        case .key(.enter):
            submitSelected()
        default:
            break
        }
    }
    
    private func submitSelected() {
        guard !provider.results.isEmpty else { return }
        
        Task {
            do {
                let item = try await provider.results[selectedIndex].getContextItem()
                done([item])
            } catch {
                print("Error loading context item: \(error)")
            }
        }
    }
}

private struct AttachmentSearchCell: View {
    var result: AttachmentSearchResult
    var selected: Bool
    
    var body: some View {
        HStack {
//            Image(systemName: result.icon)
            VStack(alignment: .leading) {
                Text(result.title)
                    .font(.headline)
                Text(result.subtitle)
                    .font(.subheadline)
                    .opacity(0.33)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .foregroundStyle(selected ? Color.white : Color.primary)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.blue)
                    .padding(.horizontal, 4)
                    .padding(.vertical, -3)
            }
        }
    }
}
