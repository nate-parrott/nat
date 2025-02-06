
import Cocoa

func createIconImage(degrees: CGFloat) -> NSImage {
    // Get all required images
    guard let baseImage = NSImage(named: "IconBase"),
          let maskImage = NSImage(named: "IconMask"),
          let pinwheelImage = NSImage(named: "IconPinwheel"),
          let screenedOverlayImage = NSImage(named: "IconScreenedOverlay"),
          let overlayImage = NSImage(named: "IconOverlay")
    else {
        fatalError("Required icon assets missing")
    }
    
    // Create context with base image size
    let size = baseImage.size
    guard let context = CGContext(data: nil,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("Could not create graphics context")
    }
    
    // Draw base layer
    if let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
    }
    
    // Create clipping mask from mask image
    if let maskCGImage = maskImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        context.clip(to: CGRect(origin: .zero, size: size), mask: maskCGImage)
    }
    
    // Draw rotated pinwheel at center
    if let pinwheelCGImage = pinwheelImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        context.saveGState()
        // Translate to center for rotation
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.rotate(by: degrees * .pi / 180)
        // Draw centered
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        context.draw(pinwheelCGImage, in: rect)
        context.restoreGState()
    }
    
    // Draw screened overlay with blend mode
    if let screenedOverlayCGImage = screenedOverlayImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        context.saveGState()
        context.setBlendMode(.screen)
        context.draw(screenedOverlayCGImage, in: CGRect(origin: .zero, size: size))
        context.restoreGState()
    }
    
    // Draw final overlay
    if let overlayCGImage = overlayImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        context.draw(overlayCGImage, in: CGRect(origin: .zero, size: size))
    }
    
    // Create final image
    guard let composedCGImage = context.makeImage() else {
        fatalError("Could not create final image")
    }
    
    return NSImage(cgImage: composedCGImage, size: size)
}
