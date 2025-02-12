import SwiftUI

struct PerFrameAnimationView<C: View>: View {
    var t: CGFloat
    @ViewBuilder var content: (CGFloat) -> C // parameter is t

    var body: some View {
        PerFrameAnimationInnerView(content: content)
            .modifier(AnimationProgressSetter(t: t))
    }
}

private struct PerFrameAnimationInnerView<C: View>: View {
    @ViewBuilder var content: (CGFloat) -> C // parameter is t
    @Environment(\.animationProgress) private var animationProgress

    var body: some View {
        content(animationProgress)
    }
}

private struct AnimationProgressSetter: AnimatableModifier {
    var t: CGFloat

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    func body(content: Content) -> some View {
        content
            .environment(\.animationProgress, t)
    }
}

// Environment key for passing the current animation progress to the view

private struct AnimationProgressKey: EnvironmentKey {
    static var defaultValue: CGFloat = 0
}

private extension EnvironmentValues {
    var animationProgress: CGFloat {
        get { self[AnimationProgressKey.self] }
        set { self[AnimationProgressKey.self] = newValue }
    }
}
