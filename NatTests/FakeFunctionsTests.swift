import XCTest
@testable import Nat

final class FakeFunctionsTests: XCTestCase {
    func testParseFakeFunctionsFromResponse() throws {
        // Test basic function call
        let basicResponse = """
        Here's a function call:
        <function>test_function({"arg1": "value1"})</function>
        And some text after.
        """
        let (basicCleanText, basicCalls) = FakeFunctions.parseFakeFunctionsFromResponse(basicResponse)
        XCTAssertEqual(basicCleanText.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces).normalizingWhitespace,
                      "Here's a function call: And some text after.")
        XCTAssertEqual(basicCalls.count, 1)
        XCTAssertEqual(basicCalls[0].name, "test_function")
        // Compare JSON by parsing and re-encoding to handle spacing differences
        let basicArgs = try JSONSerialization.jsonObject(with: basicCalls[0].arguments.data(using: .utf8)!)
        let expectedArgs = try JSONSerialization.jsonObject(with: "{\"arg1\": \"value1\"}".data(using: .utf8)!)
        XCTAssertEqual(basicArgs as! [String: String], expectedArgs as! [String: String])
        
        // Test multiple function calls
        let multiResponse = """
        First call:
        <function>func1({"x": 1})</function>
        Middle text
        <function>func2({"y": 2})</function>
        End text
        """
        let (multiCleanText, multiCalls) = FakeFunctions.parseFakeFunctionsFromResponse(multiResponse)
        XCTAssertEqual(multiCleanText.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces).normalizingWhitespace,
                      "First call: Middle text End text")
        XCTAssertEqual(multiCalls.count, 2)
        XCTAssertEqual(multiCalls[0].name, "func1")
        let multiArgs1 = try JSONSerialization.jsonObject(with: multiCalls[0].arguments.data(using: .utf8)!)
        let expectedMultiArgs1 = try JSONSerialization.jsonObject(with: "{\"x\": 1}".data(using: .utf8)!)
        XCTAssertEqual(multiArgs1 as! [String: Int], expectedMultiArgs1 as! [String: Int])
        XCTAssertEqual(multiCalls[1].name, "func2")
        let multiArgs2 = try JSONSerialization.jsonObject(with: multiCalls[1].arguments.data(using: .utf8)!)
        let expectedMultiArgs2 = try JSONSerialization.jsonObject(with: "{\"y\": 2}".data(using: .utf8)!)
        XCTAssertEqual(multiArgs2 as! [String: Int], expectedMultiArgs2 as! [String: Int])
        
        // Test malformed function call - should be skipped
        let malformedResponse = """
        Bad call:
        <function>bad_func</function>
        <function>good_func({"valid": true})</function>
        """
        let (malformedCleanText, malformedCalls) = FakeFunctions.parseFakeFunctionsFromResponse(malformedResponse)
        XCTAssertEqual(malformedCleanText.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces).normalizingWhitespace,
                      "Bad call:")
        XCTAssertEqual(malformedCalls.count, 1)
        XCTAssertEqual(malformedCalls[0].name, "good_func")
        let malformedArgs = try JSONSerialization.jsonObject(with: malformedCalls[0].arguments.data(using: .utf8)!)
        let expectedMalformedArgs = try JSONSerialization.jsonObject(with: "{\"valid\": true}".data(using: .utf8)!)
        XCTAssertEqual(malformedArgs as! [String: Bool], expectedMalformedArgs as! [String: Bool])
        
        // Test empty response
        let emptyResponse = "Just some text without functions"
        let (emptyCleanText, emptyCalls) = FakeFunctions.parseFakeFunctionsFromResponse(emptyResponse)
        XCTAssertEqual(emptyCleanText, "Just some text without functions")
        XCTAssertTrue(emptyCalls.isEmpty)
    }
}

extension String {
    var normalizingWhitespace: String {
        components(separatedBy: .whitespaces).filter({ $0 != "" }).joined(separator: " ")
    }
}
