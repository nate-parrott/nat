import XCTest
@testable import Nat
import Foundation

// MARK: - ToolContext Testing Extension
extension ToolContext {
    static func stub(workDir: URL = URL(fileURLWithPath: "/test")) -> ToolContext {
        ToolContext(
            activeDirectory: workDir,
            log: { _ in }, // No-op logger
            confirmTerminalCommands: false,
            confirmFileEdits: false,
            document: nil
        )
    }
}

final class FileEditorTests: XCTestCase {
    // MARK: - Parsing Tests
    
    func testParseBasicCreate() throws {
        let input = """
        %%%
        > Create /test/new.swift
        let x = 1
        %%%
        """
        
        let edits = try CodeEdit.edits(fromString: input, toolContext: .stub())
        XCTAssertEqual(edits.count, 1)
        
        if case .create(let path, let content) = edits[0] {
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
        
        let edits = try CodeEdit.edits(fromString: input, toolContext: .stub())
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
        
        let edits = try CodeEdit.edits(fromString: input, toolContext: .stub())
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
        > Create /test/file1.swift
        let a = 1
        %%%
        %%%
        > Replace /test/file2.swift:0
        let b = 2
        %%%
        """
        
        let edits = try CodeEdit.edits(fromString: input, toolContext: .stub())
        XCTAssertEqual(edits.count, 2)
        
        XCTAssertEqual(edits.filter { 
            if case .create = $0 { return true }
            return false
        }.count, 1)
        
        XCTAssertEqual(edits.filter {
            if case .replace = $0 { return true }
            return false
        }.count, 1)
    }
}
