import XCTest
@testable import Nat
import Foundation

// MARK: - ToolContext Testing Extension
extension ToolContext {
    static func stub(workDir: URL = URL(fileURLWithPath: "/test")) -> ToolContext {
        ToolContext(activeDirectory: .temporaryDirectory, log: { _ in () }, autorun: { true })
    }
}

final class FileEditorTests: XCTestCase {
    // MARK: - Parsing Tests

    func testMessageParser() throws {
        let input = """
        I'll add a new row to the table with another fruit.

        %%%
        > FindReplace banana.html
                    <tr>
                        <td>Orange!</td>
                    </tr>
                </table>
        ===WITH===
                    <tr>
                        <td>Orange!</td>
                    </tr>
                    <tr>
                        <td>Apple</td>
                    </tr>
                </table>
        %%%
        """
        let resp =  try EditParser.parseEditsOnly(from: input, toolContext: .stub())
        XCTAssertEqual(resp.count, 1)
    }

    func testPartialParse() throws {
        let input = """
        I'll add a new row to the table with another fruit.
        %%%
        > FindReplace banana.html
                    <tr>
                        <td>Orange!</td>
                    </tr>
        """
        let parts = try EditParser.parsePartial(string: input)
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts[0], .textLines(["I'll add a new row to the table with another fruit."]))
        if case .codeEdit(let edit) = parts[1],
           case .findReplace(path: _, find: let find, replace: _) = edit {
            XCTAssertEqual(find.count, 3)
        } else {
            XCTFail()
        }
    }

    func testFindReplace() throws {
        let input = """
        %%%
        > FindReplace /test/file.swift
        // TODO
        ===WITH===
        let x = 1
        let z = 3
        %%%
        """

        let edits = try EditParser.parseEditsOnly(from: input, toolContext: .stub())
        XCTAssertEqual(edits.count, 1)
        switch edits[0] {
        case .findReplace(path: _, find: let find, replace: let replace):
            XCTAssertEqual(find, ["// TODO"])
            XCTAssertEqual(replace, ["let x = 1", "let z = 3"])
        default: XCTFail()
        }
    }
    
    func testFindReplaceEmptyOutput() throws {
        let input = """
        %%%
        > FindReplace /test/file.swift
        // TODO
        ===WITH===
        %%%
        """

        let edits = try EditParser.parseEditsOnly(from: input, toolContext: .stub())
        XCTAssertEqual(edits.count, 1)
        switch edits[0] {
        case .findReplace(path: _, find: let find, replace: let replace):
            XCTAssertEqual(find, ["// TODO"])
            XCTAssertEqual(replace, [])
        default: XCTFail()
        }
    }

    func testApplyFindReplace() throws {
        let original = """
        let x = 1
        let y = 2
        let z = 3
        """
        let result = try applyFindReplace(existing: original, find: ["let y = 2"], replace: ["let z = 3"])
        XCTAssertEqual(result, """
        let x = 1
        let z = 3
        let z = 3
        """)
    }

    func testApplyFindReplaceEmptyOutput() throws {
        let original = """
        let x = 1
        let y = 2
        let z = 3
        """
        let result = try applyFindReplace(existing: original, find: ["let y = 2"], replace: [])
        XCTAssertEqual(result, """
        let x = 1
        let z = 3
        """)
    }

    func testAppendParsing() throws {
        let input = """
        %%%
        > Append /test/file.swift
        let x = 1
        %%%
        """

        let edits = try EditParser.parseEditsOnly(from: input, toolContext: .stub())
        XCTAssertEqual(edits.count, 1)
        switch edits[0] {
        case .append(let path, let lines):
            XCTAssertEqual(path.lastPathComponent, "file.swift")
            XCTAssertEqual(lines.lines, ["let x = 1"])
        default: XCTFail()
        }
    }

    func testApplyFindReplaceMultipleMatchesFails() throws {
        let original = """
        let x = 1
        let y = 2
        let x = 1
        """
        XCTAssertThrowsError(try applyFindReplace(existing: original, find: ["let x = 1"], replace: ["let z = 3"]))
    }
    
    func testParseBasicCreate() throws {
        let input = """
        %%%
        > Write /test/new.swift
        let x = 1
        %%%
        """
        
        let edits = try EditParser.parseEditsOnly(from: input, toolContext: .stub())
        XCTAssertEqual(edits.count, 1)
        
        if case .write(let path, let content) = edits[0] {
            XCTAssertEqual(path.lastPathComponent, "new.swift")
            XCTAssertEqual(content, "let x = 1")
        } else {
            XCTFail("Expected create edit")
        }
    }
    
    func testParseBasicReplace() throws {
        let input = """
        %%%
        > Replace /test/file.swift:0-1
        let x = 1
        let y = 2
        %%%
        """
        
        let edits = try EditParser.parseEditsOnly(from: input, toolContext: .stub())
        XCTAssertEqual(edits.count, 1)
        
        if case .replace(let path, let start, let len, let lines) = edits[0] {
            XCTAssertEqual(path.lastPathComponent, "file.swift")
            XCTAssertEqual(start, 0)
            XCTAssertEqual(len, 2)
            XCTAssertEqual(lines, ["let x = 1", "let y = 2"])
        } else {
            XCTFail("Expected replace edit")
        }
    }
    
    func testParseBasicInsert() throws {
        let input = """
        %%%
        > Insert /test/file.swift:5
        let z = 3
        %%%
        """
        
        let edits = try EditParser.parseEditsOnly(from: input, toolContext: .stub())
        XCTAssertEqual(edits.count, 1)
        
        if case .replace(let path, let start, let len, let lines) = edits[0] {
            XCTAssertEqual(path.lastPathComponent, "file.swift")
            XCTAssertEqual(start, 5)
            XCTAssertEqual(len, 0) // Insert has len=0
            XCTAssertEqual(lines, ["let z = 3"])
        } else {
            XCTFail("Expected replace edit")
        }
    }
    
    func testMultipleEdits() throws {
        let input = """
        %%%
        > Write /test/file1.swift
        let a = 1
        %%%
        %%%
        > Replace /test/file2.swift:0
        let b = 2
        %%%
        """
        
        let edits = try EditParser.parseEditsOnly(from: input, toolContext: .stub())
        XCTAssertEqual(edits.count, 2)
        
        XCTAssertEqual(edits.filter { 
            if case .write = $0 { return true }
            return false
        }.count, 1)
        
        XCTAssertEqual(edits.filter {
            if case .replace = $0 { return true }
            return false
        }.count, 1)
    }

    // MARK: - Index Adjustment Tests
    
    func testAdjustEditIndices() throws {
        let edits = [
            CodeEdit.replace(path: URL(fileURLWithPath: "/test/file.swift"), lineRangeStart: 0, lineRangeLen: 1, lines: ["line1", "line2"]), // +1 line
            CodeEdit.replace(path: URL(fileURLWithPath: "/test/file.swift"), lineRangeStart: 2, lineRangeLen: 2, lines: ["line3"]) // Should be adjusted to start at 3
        ]
        
        let fileEdits = FileEdit.edits(fromCodeEdits: edits)
        XCTAssertEqual(fileEdits.count, 1)
        XCTAssertEqual(fileEdits[0].edits.count, 2)
        
        if case .replace(_, let start, let len, _) = fileEdits[0].edits[1] {
            XCTAssertEqual(start, 3) // Original start (2) + delta from previous edit (1)
            XCTAssertEqual(len, 2)
        } else {
            XCTFail("Expected replace edit")
        }
    }
    
    func testApplyReplacement() throws {
        let original = """
        line1
        line2
        line3
        line4
        """
        
        // Test basic replacement
        var result = try applyReplacement(existing: original, lineRangeStart: 1, len: 2, lines: ["new2", "new3"])
        XCTAssertEqual(result, """
        line1
        new2
        new3
        line4
        """)
        
        // Test insert (len=0)
        result = try applyReplacement(existing: original, lineRangeStart: 1, len: 0, lines: ["inserted"])
        XCTAssertEqual(result, """
        line1
        inserted
        line2
        line3
        line4
        """)
        
        // Test invalid range throws
        XCTAssertThrowsError(try applyReplacement(existing: original, lineRangeStart: 10, len: 1, lines: ["invalid"]))
    }
    
    func testPathsWithSpaces() throws {
        let input = """
        %%%
        > Write /test/my file.swift
        let x = 1
        %%%
        """
        
        let edits = try EditParser.parseEditsOnly(from: input, toolContext: .stub())
        XCTAssertEqual(edits.count, 1)
        if case .write(let path, _) = edits[0] {
            XCTAssertEqual(path.lastPathComponent, "my file.swift")
        } else {
            XCTFail("Expected write edit")
        }
        
        let input2 = """
        %%%
        > FindReplace /test/my file with spaces.swift
        let x = 1
        ===WITH===
        let y = 2
        %%%
        """
        
        let edits2 = try EditParser.parseEditsOnly(from: input2, toolContext: .stub())
        XCTAssertEqual(edits2.count, 1)
        if case .findReplace(let path, _, _) = edits2[0] {
            XCTAssertEqual(path.lastPathComponent, "my file with spaces.swift")
        } else {
            XCTFail("Expected findreplace edit")
        }
    }

    func testEmptyPartsBetweenEditsOmitted() throws {
        let input = """
        %%%
        > Write /test/file1.swift
        let x = 1
        %%%

        %%%
        > Write /test/file2.swift
        let y = 2
        %%%
        """
        var errs = [String]()
        let parts = try EditParser.parse(string: input, toolContext: .stub(), parseErrors: &errs)
        XCTAssertEqual(parts.count, 2)
        for part in parts {
            if case .textLines = part {
                XCTFail("Should not have any text parts")
            }
        }
    }
    
    func testMalformedEditsDetected() throws {
        let inputEmpty = """
        no edits here!
        I'll add a new row to the table with another fruit.

        %whee
        // hey!
        ===WITH===!!
        
        hey!
        
        """
        
        try XCTAssertTrue(!EditParser.containsEditsOrMalformedEdits(string: inputEmpty))
        
        let inputMalformed = """
        I'll add a new row to the table with another fruit.

        %%%
        > FindReplace banana.html
                    <tr>
                        <td>Orange!</td>
                    </tr>
                </table>
        ===WITH===
                    <tr>
                        <td>Orange!</td>
                    </tr>
                    <tr>
                        <td>Apple</td>
                    </tr>
                </table>
        ===WITH===
        hehehe
        %%%
        """

        try XCTAssertTrue(EditParser.containsEditsOrMalformedEdits(string: inputMalformed))
    }
    
    func testMultipleWithsGenerateError() throws {
        let input = """
        I'll add a new row to the table with another fruit.

        %%%
        > FindReplace banana.html
                    <tr>
                        <td>Orange!</td>
                    </tr>
                </table>
        ===WITH===
                    <tr>
                        <td>Orange!</td>
                    </tr>
                    <tr>
                        <td>Apple</td>
                    </tr>
                </table>
        ===WITH===
        hehehe
        %%%
        """
        var errs = [String]()
        let resp =  try EditParser.parseEditsOnly(from: input, toolContext: .stub(), parseErrors: &errs)
        XCTAssertEqual(resp.count, 0)
        XCTAssert(errs.count > 0)
    }
}
