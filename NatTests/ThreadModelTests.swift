import XCTest
@testable import Nat

extension TaggedLLMMessage {
    var text: String? {
        if case .text(let text) = content.first {
            return text
        }
        return nil
    }
}

final class ThreadModelTests: XCTestCase {
    func testTruncateTaggedLLMessages() {
        // Create test messages with simple indices
        let messages = (0..<15).map { i in
            TaggedLLMMessage(role: .assistant, content: [.text("Message \(i)")])
        }
        
        // Test 1: When array is shorter than keepFirst + keepLast
        let shortResult = messages[..<5].asArray.omitOldMessages(keepFirstN: 2, keepLastN: 4)
        XCTAssertEqual(shortResult.count, 5, "Short arrays should not be truncated")
        
        // Test 2: Basic truncation with small values
        let result = messages.omitOldMessages(keepFirstN: 2, keepLastN: 3, round: 4)
        XCTAssertEqual(result.count, 6, "Should have 2 start + 1 system + 3 end messages")
        XCTAssertEqual(result[0].text, "Message 0")
        XCTAssertEqual(result[1].text, "Message 1")
        XCTAssertEqual(result[2].text, "[Old messages omitted]")

        // Test 3: Verify rounding behavior
        let roundedResult = messages.omitOldMessages(keepFirstN: 2, keepLastN: 3, round: 5)
        // Cutoff should be:
        // Swift.max(2, (15 - 3).round(5))
        // = max(2, 10)
        // so keep first 2, last 10-15 = 7 + omission message = 8
        XCTAssertEqual(roundedResult.count, 8)
        XCTAssertTrue(roundedResult[2].text?.contains("omitted") ?? false)
        
        // Test 4: Verify function calls/responses are cleared at truncation points
        var messagesWithFunctions = messages
        messagesWithFunctions[1].functionCalls = [.init(name: "test", arguments: "{}")]
        messagesWithFunctions[12].functionResponses = [.init(functionName: "test", content: [])]

        let functionResult = messagesWithFunctions.omitOldMessages(keepFirstN: 2, keepLastN: 3, round: 4)
        XCTAssertTrue(functionResult[1].functionCalls.isEmpty, "Function calls should be cleared at truncation point")
        XCTAssertTrue(functionResult[3].functionResponses.isEmpty, "Function responses should be cleared at truncation point")
    }
}
