import SwiftUI

private final class DockAnimationRequester: ObservableObject {
    @Published var animating: Bool = false {
        didSet {
            if animating {
                IconAnimator.shared.requestAnimation()
            } else {
                IconAnimator.shared.releaseAnimation()
            }
        }
    }
    
    deinit {
        if animating {
            IconAnimator.shared.releaseAnimation()
        }
    }
}

extension View {
    func requestsDockSpin(_ active: Bool) -> some View {
        self.modifier(DockSpinModifier(active: active))
    }
}

private struct DockSpinModifier: ViewModifier {
    @StateObject private var requester = DockAnimationRequester()
    let active: Bool
    
    func body(content: Content) -> some View {
        content.onChange(of: active) { newValue in
            requester.animating = newValue
        }
        .onAppear {
            requester.animating = active
        }
    }
}