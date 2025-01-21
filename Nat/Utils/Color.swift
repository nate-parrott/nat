import AppKit

extension NSColor {
    func withAlphaComponentSafe(_ alpha: CGFloat) -> NSColor {
        NSColor(name: nil) { _ in
            self.withAlphaComponent(alpha)
        }
    }
}
