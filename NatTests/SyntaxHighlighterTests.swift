import XCTest
@testable import Nat

final class SyntaxHighlighterTests: XCTestCase {
    func dumpRuns(_ runs: [TokenRun]) {
        print("Tokens:")
        for (i, run) in runs.enumerated() {
            print("[\(i)] \(run.text.debugDescription) - \(String(describing: run.tokenType))")
        }
    }
    
    func testBasicSwiftHighlighting() {
        let input = """
        // This is a comment
        let x = 42
        let str = "hello world"
        """
        
        let runs = LanguagePack.swift.tokenize(input)
        dumpRuns(runs)
        
        // Test comment
        XCTAssertEqual(runs[0].text, "// This is a comment")
        XCTAssertEqual(runs[0].tokenType, .comment)
        
        // Test basic line with spacing
        XCTAssertEqual(runs[2].text, "let")
        XCTAssertEqual(runs[2].tokenType, .keyword)
        XCTAssertEqual(runs[4].text, "x")
        XCTAssertEqual(runs[4].tokenType, .identifier)
        XCTAssertEqual(runs[6].text, "=")
        XCTAssertEqual(runs[6].tokenType, .operatorToken)
        XCTAssertEqual(runs[8].text, "42")
        XCTAssertEqual(runs[8].tokenType, .numberLiteral)
    }
    
    func testSwiftTypeAndBooleans() {
        let input = "class MyClass: NSObject { let flag = true }"
        let runs = LanguagePack.swift.tokenize(input)
        dumpRuns(runs)
        
        // Only test the semantic tokens, ignore whitespace
        let semanticRuns = runs.filter { $0.tokenType != nil }
        XCTAssertEqual(semanticRuns.map { $0.tokenType }, [
            .keyword,        // class
            .typeIdentifier, // MyClass
            .typeIdentifier, // NSObject
            .keyword,        // let
            .identifier,     // flag
            .operatorToken,  // =
            .booleanLiteral // true
        ])
    }
    
    func testMultilineCommentStyles() {
        let input = """
        // Line comment
        /* Block comment */
        let x = 1
        """
        
        let runs = LanguagePack.swift.tokenize(input)
        dumpRuns(runs)
        
        let comments = runs.filter { $0.tokenType == .comment }
        XCTAssertEqual(comments.count, 2)
        XCTAssertEqual(comments[0].text, "// Line comment")
        XCTAssertEqual(comments[1].text, "/* Block comment */")
    }
    
    func testAttributedStringConversion() {
        let run = TokenRun(text: "let", tokenType: .keyword)
        let attrStr = run.toAttributedString()
        XCTAssertEqual(attrStr.characters.count, 3)
        XCTAssertNotNil(attrStr.runs.first?.foregroundColor)
    }
}