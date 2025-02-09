import XCTest
@testable import Nat

final class CellModelTests: XCTestCase {
    // Helper to create log cell models
    private func logCell(_ log: UserVisibleLog, id: String = "test") -> MessageCellModel {
        MessageCellModel(id: id, content: .logs([log]))
    }
    
    func testClusterLogs() {
        // Test that non-log messages aren't clustered
        let messages = [
            MessageCellModel(id: "1", content: .userMessage(text: "Test", attachments: [])),
            MessageCellModel(id: "2", content: .assistantMessage("Response")),
            MessageCellModel(id: "3", content: .error("Error"))
        ]
        let result = clusterLogs(messages)
        XCTAssertEqual(result, messages, "Non-log messages should remain unchanged")
        
        // Test clustering related logs
        let searchLogs = [
            logCell(.codeSearch("query1"), id: "1"),
            logCell(.effort("high"), id: "2"),
            logCell(.grepped("pattern"), id: "3"),
            logCell(.listedFiles, id: "4"),
            logCell(.readFile(URL(fileURLWithPath: "test.txt")), id: "5"),
        ]
        let clusteredSearch = clusterLogs(searchLogs)
        XCTAssertEqual(clusteredSearch.count, 1, "Related logs should be clustered")
        if case .logs(let logs) = clusteredSearch[0].content {
            XCTAssertEqual(logs.count, 5, "All related logs should be in one cluster")
        } else {
            XCTFail("Expected logs content")
        }
        
        // Test that non-related logs don't cluster
        let mixedLogs = [
            logCell(.codeSearch("query"), id: "1"),
            logCell(.webSearch("test"), id: "2"),
            logCell(.toolError("error"), id: "3"),
        ]
        let clusteredMixed = clusterLogs(mixedLogs)
        XCTAssertEqual(clusteredMixed.count, 3, "Unrelated logs should not cluster")
        
        // Test that non-log messages break clusters
        let interleavedLogs = [
            logCell(.codeSearch("query1"), id: "1"),
            MessageCellModel(id: "2", content: .userMessage(text: "Test", attachments: [])),
            logCell(.codeSearch("query2"), id: "3"),
        ]
        let clusteredInterleaved = clusterLogs(interleavedLogs)
        XCTAssertEqual(clusteredInterleaved.count, 3, "Messages should prevent log clustering")
        
        // Test empty input
        XCTAssertEqual(clusterLogs([]), [], "Empty input should return empty array")
        
        // Test singleton input
        let single = logCell(.codeSearch("query"))
        XCTAssertEqual(clusterLogs([single]), [single], "Single log should remain unchanged")
        
        // Test edits clustering behavior
        let edits = [
            logCell(.edits(.init(paths: [URL(fileURLWithPath: "test.txt")], accepted: true)), id: "1"),
            logCell(.edits(.init(paths: [URL(fileURLWithPath: "test2.txt")], accepted: false)), id: "2"),
        ]
        let clusteredEdits = clusterLogs(edits)
        XCTAssertEqual(clusteredEdits.count, 2, "Edit logs should not cluster")
    }
}
