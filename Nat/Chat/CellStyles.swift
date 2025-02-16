import SwiftUI

//struct CellBackdropModifier: ViewModifier {
//    var enabled: Bool = true
//    var tint: Color? = nil
//    
//    func body(content: Content) -> some View {
//        if enabled {
//            let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
//            content
//                .padding(.horizontal, 8)
//                .padding(.vertical, 6)
//                .overlay {
//                    shape
//                        .strokeBorder(Color.primary.opacity(0.1))
//                }
//                .clipShape(shape)
//                .background {
//                    if let tint {
//                        tint
//                            .overlay {
//                                LinearGradient(colors: [Color.white, Color.white.opacity(0)], startPoint: .top, endPoint: .bottom)
//                                    .opacity(0.1)
//                            }
//                            .clipShape(shape)
//                            .shadow(color: Color.blue.opacity(0.1), radius: 4, x: 0, y: 1)
//                    } else {
//                        shape
//                            .fill(.thickMaterial)
//                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
//                    }
//                }
//        } else {
//            content
//        }
//    }
//}

struct TintedBackdropModifier: ViewModifier {
    var tint: Color = .blue
    
    func body(content: Content) -> some View {
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
                tint
                    .overlay {
                        LinearGradient(colors: [Color.white, Color.white.opacity(0)], startPoint: .top, endPoint: .bottom)
                            .opacity(0.1)
                    }
                    .clipShape(shape)
                    .shadow(color: tint.opacity(0.1), radius: 4, x: 0, y: 1)
            }
    }
}

//struct TerminalCellModifier: ViewModifier {
//    func body(content: Content) -> some View {
//        content.fontDesign(.monospaced)
//            .foregroundStyle(.white)
//            .modifier(TintedBackdropModifier(tint: Color(hex: 0x101020)))
//    }
//}

struct InsetCellModifier: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .overlay {
                shape
                    .strokeBorder(Color.primary.opacity(0.1))
            }
            .background {
                VStack(spacing: 0) {
                    LinearGradient(colors: [Color.primary.opacity(0.1), Color.primary.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 12)
                    Color.primary.opacity(0.02)
                }
            }
            .clipShape(shape)
    }
}

struct ClickForDetailModifier: ViewModifier {
    var id: String
    @EnvironmentObject private var detailCoord: DetailCoordinator
    
    func body(content: Content) -> some View {
        content.modifier(ClickableCellInteraction(action: {
            detailCoord.clickedCellId = id
        }))
        .onAppear {
            detailCoord.implicitlyShownCellId = id
        }
    }
}

struct ClickableCellInteraction: ViewModifier {
    var action: () -> Void
    
    func body(content: Content) -> some View {
        Button(action: action) {
            content
        }
        .buttonStyle(ClickableCellButtonStyle())
    }
}

private struct ClickableCellButtonStyle: ButtonStyle {
    @State private var hovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        let offset: CGFloat = configuration.isPressed ? 1 : (hovered ? -2 : 0)
        
        configuration.label
            .onHover(perform: { self.hovered = $0 })
            .background {
                if !configuration.isPressed && hovered {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .foregroundStyle(Color.black)
                        .reverseMask {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .offset(y: -max(0, -offset))
                        }
                        .opacity(0.1)
                        .offset(y: max(0, -offset))
                }
            }
            .offset(y: offset)
            .animation(.spring(duration: 0.2, bounce: 0.5, blendDuration: 0.1), value: offset)
    }
}
