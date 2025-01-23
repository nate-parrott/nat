import SwiftUI

/// A shimmering loading indicator that appears as a blue bar with animated white gradient
struct Shimmer: View {
//    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Color.blue
                .overlay(
                    Color.white
                        .modifier(ShimmerMask())
                )
                .mask(Rectangle())
//                .onAppear {
//                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
//                        phase = 1.0
//                    }
//                }
        }
        .frame(height: 4)
    }
}

struct ShimmerMask: ViewModifier {
    var delay: TimeInterval = 1
    private let animation = Animation.easeInOut(duration: 1).repeatForever(autoreverses: false)

    @State private var endState = false

    func body(content: Content) -> some View {
        content
            .mask {
                LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(1), Color.black.opacity(0)], startPoint: startPoint, endPoint: endPoint)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(animation) {
                        endState.toggle()
                    }
                }
            }
    }

    private var startPoint: UnitPoint {
        .init(x: endState ? 1 : -1, y: 0)
    }

    private var endPoint: UnitPoint {
        .init(x: startPoint.x + 1, y: 0)
    }
}

