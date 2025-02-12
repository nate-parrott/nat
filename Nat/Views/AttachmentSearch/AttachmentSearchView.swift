import SwiftUI

struct AttachmentSearchView: View {
    let done: ([ContextItem]) -> Void
    @Environment(\.document) private var document
    @StateObject private var provider = AttachmentSearchProvider()
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var focusDate: Date?
    
    var body: some View {
        VStack(spacing: 12) {
            InputTextField(text: $searchText,
                         options: .init(placeholder: "Search attachments...", wantsUpDownArrowEvents: true),
                         focusDate: focusDate,
                         onEvent: handleTextFieldEvent)
                .frame(height: 30)
            
            List(provider.results.indices, id: \.self) { index in
                let result = provider.results[index]
                HStack {
                    Image(systemName: result.icon)
                    VStack(alignment: .leading) {
                        Text(result.title)
                            .font(.headline)
                        Text(result.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(index == selectedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
                .onTapGesture {
                    selectedIndex = index
                }
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    done([])
                }
                if !provider.results.isEmpty {
                    Button("Add Selected") {
                        submitSelected()
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 400, height: 300)
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
