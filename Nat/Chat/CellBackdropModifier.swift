import SwiftUI

struct CellBackdropModifier: ViewModifier {
    var enabled: Bool
    var tint: Color?
    
    func body(content: Content) -> some View {
        if enabled {
            content
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1))
                }
                .background {
                    if let tint {
                        tint
                            .overlay {
                                LinearGradient(colors: [Color.white, Color.white.opacity(0)], startPoint: .top, endPoint: .bottom)
                                    .opacity(0.1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .shadow(color: Color.blue.opacity(0.1), radius: 4, x: 0, y: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.thickMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                    }
                }
        } else {
            content
        }
    }
}
