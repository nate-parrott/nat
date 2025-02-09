import SwiftUI

struct ShinyButtonStyle: ButtonStyle {
    let tintColor: Color
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                ZStack {
                    tintColor
                    LinearGradient(colors: [Color.white.opacity(0.2), Color.black.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                        .blendMode(.overlay)
                }
            }
            .foregroundColor(.white)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
            .animation(.spring(duration: 0.2), value: isHovered)
            .animation(.spring(duration: 0.1), value: configuration.isPressed)
            .onHover { hover in
                isHovered = hover
            }
    }
}
