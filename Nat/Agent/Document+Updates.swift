//
//  Document+Changes.swift
//  Nat
//
//  Created by Nate Parrott on 3/7/25.
//

extension Document {
    func fetchUpdates() async throws -> ContextItem? {
        // TODO: read thread, check hashes of file snippets, re-read them and make sure hashes match, or insert a status item saying "File [XYZ] was changed on disk"
        // TODO: Read thread, check hashes of last file_tree call; call again and notify if file tree changed
        return nil
    }
}
