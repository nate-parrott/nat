//
//  NatTests.swift
//  NatTests
//
//  Created by nate parrott on 1/22/25.
//

import XCTest

let secret_var = "xyz"

final class SecretTest: XCTestCase {
    func testExample() throws {
        print("The log secret phrase is CEDAR")
        XCTAssertEqual(secret_var, "abc")
    }
}
