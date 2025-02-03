import XCTest
@testable import Nat

final class SwiftSyntaxCheckerTests: XCTestCase {
    func testValidSyntax() async throws {
        let code = """
        struct Test {
            let x = 1
            func foo() { print(x) }
        }
        """
        let result = await checkSwiftSyntax(code: code)
        switch result {
        case .ok:
            break // Expected
        case .failed(let error):
            XCTFail("Expected syntax to be valid but got error: \(error)")
        }
    }
    
    func testInvalidSyntax() async throws {
        let code = """
        struct Test {
            let x = // Missing value
            func foo() { print(x)
        """
        let result = await checkSwiftSyntax(code: code)
        switch result {
        case .ok:
            XCTFail("Expected syntax to be invalid")
        case .failed:
            break // Expected
        }
    }
    
    func testEmptyString() async throws {
        let result = await checkSwiftSyntax(code: "")
        if case .failed = result {
            XCTFail("Empty string should be valid Swift syntax")
        }
    }
}