import XCTest
@testable import Nat
import SwiftUI

final class AttributedStringTests: XCTestCase {
    func testSplitEmptyString() {
        // Match String.split behavior - an empty string returns an empty array
        let str = AttributedString("")
        XCTAssertEqual(str.split(separator: "\n"), [])
        
        // Verify this matches String behavior
        XCTAssertEqual("".split(separator: "\n"), [])
    }
    
    func testSplitSingleLine() {
        let str = AttributedString("hello world")
        XCTAssertEqual(str.split(separator: "\n"), [AttributedString("hello world")])
    }
    
    func testSplitOnNewline() {
        let str = AttributedString("line1\nline2")
        XCTAssertEqual(str.split(separator: "\n"), [
            AttributedString("line1"),
            AttributedString("line2")
        ])
    }
    
    func testSplitMultipleNewlines() {
        let str = AttributedString("line1\n\nline3")
        XCTAssertEqual(str.split(separator: "\n"), [
            AttributedString("line1"),
            AttributedString(""),
            AttributedString("line3")
        ])
    }
    
    func testSplitTrailingNewline() {
        let str = AttributedString("line1\n")
        XCTAssertEqual(str.split(separator: "\n"), [
            AttributedString("line1")
        ])
    }
    
    func testSplitLeadingNewline() {
        let str = AttributedString("\nline2")
        XCTAssertEqual(str.split(separator: "\n"), [
            AttributedString(""),
            AttributedString("line2")
        ])
    }
}
