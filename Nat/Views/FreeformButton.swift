import SwiftUI

enum FreeformButtonState: Equatable {
    case none
    case hovered
    case pressed
    case disabled
}

struct FreeformButton<C: View>: View {
    var action: () -> ()
    @ViewBuilder var content: (FreeformButtonState) -> C

    var body: some View {
        Button(action: action) {
            EmptyView()
        }
        .buttonStyle(FreeformButtonStyle(content: content))
    }
}

private struct FreeformButtonStyle<C: View>: ButtonStyle {
    @ViewBuilder var content: (FreeformButtonState) -> C
    
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        content(state(pressed: configuration.isPressed))
            .onHover(perform: { self.hovered = $0 })
    }
    
    func state(pressed: Bool) -> FreeformButtonState {
        if !enabled { return .disabled }
        if pressed { return .pressed }
        return hovered ? .hovered : .none
    }
}
