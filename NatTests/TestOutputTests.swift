import XCTest
import os.log
import CoreGraphics
import AppKit
@testable import Nat

final class TestOutputTests: XCTestCase {
    func testInspectOutput() throws {
        let size = NSSize(width: 200, height: 200)
        let image = NSImage(size: size)
        
        image.lockFocus()
        NSColor.red.setFill()
        let rect = NSRect(x: 50, y: 50, width: 100, height: 100)
        let path = NSBezierPath(ovalIn: rect)
        path.fill()
        image.unlockFocus()
        
        if let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            let path = "/var/folders/st/sgrnb_7j09l94_1m1yhqd23c0000gn/T/nat_inspect_0/circle.png"
            try pngData.write(to: URL(fileURLWithPath: path))
        }
    }
}
