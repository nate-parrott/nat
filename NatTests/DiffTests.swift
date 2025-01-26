
//import Differ

//struct Diff: Equatable {
//    enum Line: Equatable {
//        case same(String)
//        case insert(String)
//        case delete(String)
//        case collapsed([Line])
//    }
//
//    var lines: [Line]
//
//    static func collapseRunsOfSames(_ lines: [Line]) -> [Line] {

import XCTest
@testable import Nat
import Foundation

final class DiffTests: XCTestCase {
    // MARK: - Parsing Tests

    func testSame() throws {
        let str = """
        let x = 1
        let y = 2
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let diff = Diff.from(before: str.lines, after: str.lines, collapseSames: false)
        XCTAssertEqual(diff, Diff(lines: [
            .same("let x = 1"),
            .same("let y = 2"),
        ]))
    }

    func testSingleInsert() throws {
        let str = """
        let x = 1
        let y = 2
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let str2 = """
        let x = 1
        let xy = 1.5
        let y = 2
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        let diff = Diff.from(before: str.lines, after: str2.lines, collapseSames: false)
        XCTAssertEqual(diff, Diff(lines: [
            .same("let x = 1"),
            .insert("let xy = 1.5"),
            .same("let y = 2"),
        ]))
    }

    func testSingleDelete() throws {
        let str = """
        let x = 1
        let y = 2
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let str2 = """
        let x = 1
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        let diff = Diff.from(before: str.lines, after: str2.lines, collapseSames: false)
        XCTAssertEqual(diff, Diff(lines: [
            .same("let x = 1"),
            .delete("let y = 2"),
        ]))
    }

    func testSingleReplace() throws {
        let str = """
        let x = 1
        let y = 2
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let str2 = """
        let x = 1
        let y = 3
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        let diff = Diff.from(before: str.lines, after: str2.lines, collapseSames: false)
        XCTAssertEqual(diff, Diff(lines: [
            .same("let x = 1"),
            .insert("let y = 3"),
            .delete("let y = 2"),
        ]))
    }

    func testSequentialInserts() throws {
        let str = """
        let x = 1
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let str2 = """
        let x = 1
        let y = 2
        let z = 3
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        let diff = Diff.from(before: str.lines, after: str2.lines, collapseSames: false)
        XCTAssertEqual(diff, Diff(lines: [
            .same("let x = 1"),
            .insert("let y = 2"),
            .insert("let z = 3"),
        ]))
    }

    func testSequentialDeletes() throws {
        let str = """
        let x = 1
        let y = 2
        let z = 3
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let str2 = """
        let x = 1
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        let diff = Diff.from(before: str.lines, after: str2.lines, collapseSames: false)
        XCTAssertEqual(diff, Diff(lines: [
            .same("let x = 1"),
            .delete("let y = 2"),
            .delete("let z = 3"),
        ]))
    }

    func testInsertDelete() throws {
        let str = """
        let y = 2
        let z = 3
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let str2 = """
        let x = 1
        let y = 2
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        let diff = Diff.from(before: str.lines, after: str2.lines, collapseSames: false)
        XCTAssertEqual(diff, Diff(lines: [
            .insert("let x = 1"),
            .same("let y = 2"),
            .delete("let z = 3"),
        ]))
    }
}


