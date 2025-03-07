//
//  Document+ProjectContext.swift
//  Nat
//
//  Created by Nate Parrott on 3/7/25.
//

extension Document {
    func fetchProjectContext() async throws -> ContextItem? {
        return nil // TODO: Fetch first ~20 lines of file tree, first ~50 lines of git diff OR last ~50 lines of last commit, first ~20 lines of current file in xcode
    }
}
