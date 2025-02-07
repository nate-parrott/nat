import SwiftUI

struct AttachmentPill: View {
    let item: ContextItem
    let onRemove: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        let (icon, summary) = item.summary
        
        HStack {
            Label(summary, systemImage: icon)
            if item.loading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(both: 16)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .modifier(FloatingXModifier(onClick: onRemove))
    }
}

// Written by Phil
struct FloatingXModifier: ViewModifier {
    let onClick: () -> Void
    
    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            Button(action: onClick) {
                Image(systemName: "xmark")
                    .foregroundColor(.primary)
                    .bold()
                    .help(Text("Remove"))
                    .font(.system(size: 14))
            }
            .frame(both: 24)
            .onHover { hovering in
                isHoveringOnButton = hovering
            }
            .buttonStyle(PlainButtonStyle())
            .background(Material.thickMaterial)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.1), radius: 4)
            .padding(.trailing, -8)
            .padding(.top, -8)
            .opacity(isHovering || isHoveringOnButton ? 1 : 0)
            .animation(.easeInOut(duration: 0.1), value: isHovering)
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    @State private var isHovering: Bool = false
    @State private var isHoveringOnButton: Bool = false
}

