//
//  Document+ProjectContext.swift
//  Nat
//
//  Created by Nate Parrott on 3/7/25.
//

import Foundation

extension Document {
    func fetchProjectContext() async throws -> ContextItem? {
        guard let folder = store.model.folder else {
            return nil // No active Xcode project
        }
        
        // Run all context-gathering operations concurrently
        async let fileTreeContext = getFileTreeContext(projectURL: folder)
        async let gitContext = getGitContext(projectURL: folder)
        async let currentFileContext = getCurrentFileContext()
        
        // Await all results
        let contextParts = await [
            fileTreeContext,
            gitContext,
            currentFileContext
        ].compactMap { $0 } // Remove nil values
        
        guard !contextParts.isEmpty else {
            return nil
        }
        
        // Combine all context parts
        let finalContent = contextParts.joined(separator: "\n\n")
        Swift.print("<PROJECT CTX>")
        Swift.print(finalContent)
        Swift.print("</PROJECT CTX>")
        return .proactiveContext(title: "Project Context", content: finalContent)
    }
    
    // Helper to get file tree context
    private func getFileTreeContext(projectURL: URL) async -> String? {
        let fileTree = FileTree.fullTree(url: projectURL)
        let fileTreeLines = fileTree.components(separatedBy: .newlines)
        let limitedFileTree = fileTreeLines.prefix(20).joined(separator: "\n")
        return "# Project File Tree (first 20 lines)\n\(limitedFileTree)"
    }
    
    // Helper to get git diff or last commit information
    private func getGitContext(projectURL: URL) async -> String? {
        do {
            // First try to get git diff
            let gitDiffProcess = Process()
            gitDiffProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            gitDiffProcess.arguments = ["--no-pager", "diff", "--unified=3"]
            gitDiffProcess.currentDirectoryURL = projectURL
            
            let pipe = Pipe()
            gitDiffProcess.standardOutput = pipe
            
            try gitDiffProcess.run()
            // Important: read data before waitUntilExit
            guard let data = try pipe.fileHandleForReading.readToEnd() else {
                return nil
            }
            gitDiffProcess.waitUntilExit()
            
            if gitDiffProcess.terminationStatus == 0 {
                let diffOutput = String(data: data, encoding: .utf8) ?? ""
                if !diffOutput.isEmpty {
                    // Convert to diff format
                    let diff = Diff.fromGitOutput(diffOutput)
                    // Get first ~50 lines or all if less
                    let diffLines = diff.lines.prefix(50).map { line -> String in
                        switch line {
                        case .same(let str): return str
                        case .insert(let str): return "+ \(str)"
                        case .delete(let str): return "- \(str)"
                        case .collapsed(let lines): return "... (\(lines.count) unchanged lines)"
                        }
                    }
                    return "# Git Diff (first 50 lines)\n\(diffLines.joined(separator: "\n"))"
                } else {
                    return await getLastCommitContext(projectURL: projectURL)
                }
            }
            return nil
        } catch {
            Swift.print("Error getting git information: \(error)")
            return nil
        }
    }
    
    // Helper to get last commit information
    private func getLastCommitContext(projectURL: URL) async -> String? {
        do {
            let lastCommitProcess = Process()
            lastCommitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            lastCommitProcess.arguments = ["--no-pager", "show", "--unified=3", "-s"]
            lastCommitProcess.currentDirectoryURL = projectURL
            
            let commitPipe = Pipe()
            lastCommitProcess.standardOutput = commitPipe
            
            try lastCommitProcess.run()
            guard let commitData = try commitPipe.fileHandleForReading.readToEnd() else {
                return nil
            }
            lastCommitProcess.waitUntilExit()
            
            if lastCommitProcess.terminationStatus == 0 {
                let commitOutput = String(data: commitData, encoding: .utf8) ?? ""
                let limitedCommitOutput = commitOutput.components(separatedBy: .newlines).prefix(50).joined(separator: "\n")
                return "# Last Git Commit\n\(limitedCommitOutput)"
            }
            return nil
        } catch {
            Swift.print("Error getting last commit: \(error)")
            return nil
        }
    }
    
    // Helper to get current file context
    private func getCurrentFileContext() async -> String? {
        guard let currentXcodeFileURL = try? await Scripting.xcodeState().file else {
            return nil
        }
        do {
            var encoding: String.Encoding = .utf8
            let fileContent = try String(contentsOf: currentXcodeFileURL, usedEncoding: &encoding)
            let fileLines = fileContent.components(separatedBy: .newlines)
            let limitedFileContent = fileLines.prefix(20).joined(separator: "\n")
            
            // Get relative path if possible
            let relativePathString = currentXcodeFileURL.lastPathComponent
            
            return "# Current File in Xcode: \(relativePathString) (first 20 lines)\n\(limitedFileContent)"
        } catch {
            Swift.print("Error reading current file: \(error)")
            return nil
        }
    }
}
