import SwiftUI

struct CellBackdropModifier: ViewModifier {
    var enabled: Bool = true
    var tint: Color? = nil
    
    func body(content: Content) -> some View {
        if enabled {
            let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
            content
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .overlay {
                    shape
                        .strokeBorder(Color.primary.opacity(0.1))
                }
                .clipShape(shape)
                .background {
                    if let tint {
                        tint
                            .overlay {
                                LinearGradient(colors: [Color.white, Color.white.opacity(0)], startPoint: .top, endPoint: .bottom)
                                    .opacity(0.1)
                            }
                            .clipShape(shape)
                            .shadow(color: Color.blue.opacity(0.1), radius: 4, x: 0, y: 1)
                    } else {
                        shape
                            .fill(.thickMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                    }
                }
        } else {
            content
        }
    }
}
