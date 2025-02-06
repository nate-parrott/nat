import AppKit

extension NSImage {
    /// Returns the PNG data representation of the image
    /// - Returns: PNG data, or nil if conversion failed
    func pngData() -> Data? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
}