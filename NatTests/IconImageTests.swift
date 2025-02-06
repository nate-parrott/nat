import XCTest
@testable import Nat

final class IconImageTests: XCTestCase {
    func testCreateIconImage() throws {
        let image = createIconImage(degrees: 0)
        XCTAssertNotNil(image)
        XCTAssertFalse(image.size.width.isZero)
        XCTAssertFalse(image.size.height.isZero)
        
        // Save to temp file for inspection
        guard let imageData = image.pngData() else {
            XCTFail("Could not create PNG data")
            return
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("icon_test.png")
        try imageData.write(to: tempURL)
        NSLog("Icon saved to: %@", tempURL.path)
    }
}
