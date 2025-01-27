//
//  ContextItem+FromFile.swift
//  Nat
//
//  Created by nate parrott on 1/27/25.
//

import Foundation
import ChatToys

extension ContextItem {
    static func from(url: URL, projectFolder: URL?) async throws -> ContextItem {
        // Handle web URLs
        if ["http", "https"].contains(url.scheme?.lowercased()) {
            return .url(url)
        }
        
        // Handle images
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic"]
        let fileExtension = url.pathExtension.lowercased()
        if imageExtensions.contains(fileExtension),
           url.isFileURL,
           let image = ChatUINSImage(contentsOf: url) {
            return try .image(image.asLLMImage())
        }
        
        // Handle text files
        let content = try String(contentsOf: url)
        if let projectFolder, let relativePath = url.asPathRelativeTo(base: projectFolder) {
            return .textFile(filename: relativePath, content: content)
        } else {
            return .textFile(filename: url.lastPathComponent, content: content)
        }
    }
}
