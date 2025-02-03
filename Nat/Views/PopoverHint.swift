import SwiftUI

/// A small info button that shows a popover with text when tapped
struct PopoverHint<Content: View>: View {
    let content: () -> Content
    @State private var showingPopover = false
    
    var body: some View {
        Button(action: { showingPopover.toggle() }) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopover) {
            ScrollView {
                content()
                    .padding()
                    .lineSpacing(6)
            }
                .frame(width: 300, height: 300)
                .foregroundStyle(Color.primary)
//                .fixedSize()
//                .presentationCompactAdaptation(.popover)
        }
    }
}
