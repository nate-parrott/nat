import SwiftUI
import AppKit

class SwiftUIFloatingPanel: NSPanel {
    private var hostingView: NSHostingView<AnyView>
    
    var hostedView: AnyView {
        get { hostingView.rootView }
        set { hostingView.rootView = newValue }
    }
    
    init(view: AnyView) {
        self.hostingView = NSHostingView(rootView: view)
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.titlebarAppearsTransparent = false
        self.isMovableByWindowBackground = true
        self.animationBehavior = .documentWindow
        
        // Center on screen
        self.center()
        
        self.contentView = hostingView
    }
}