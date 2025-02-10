import XCTest
import os.log
@testable import Nat

final class TestOutputTests: XCTestCase {
    func testPrintOutput() {
        os_log(.default, "This is a test output line")
        os_log(.default, "This is another test output line")
        XCTAssertTrue(true) // Simple assertion to make the test pass
    }
}