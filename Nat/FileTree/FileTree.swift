import Foundation
import AppKit

private struct Entry {
    var dirPath: [String] // Path items from root dir, may be []
    var leafChildNames: [String] // e.g. ["a.txt", "b.txt"]

    static func formatAsString(entries: [Entry]) -> String {
        // Group entries by their first directory component (or empty for root)
        var entriesByFirstComponent: [String?: [Entry]] = [:]
        for entry in entries {
            let key = entry.dirPath.first
            if var existing = entriesByFirstComponent[key] {
                existing.append(entry)
                entriesByFirstComponent[key] = existing
            } else {
                entriesByFirstComponent[key] = [entry]
            }
        }
        
        func formatLevel(entries: [Entry], indent: String, fullPath: [String] = []) -> [String] {
            var lines: [String] = []
            
            // First, handle files at this level
            let filesAtLevel = entries.filter { $0.dirPath.isEmpty }
            let allFiles = filesAtLevel.flatMap { $0.leafChildNames }.sorted()
            
            // Then handle subdirectories
            let entriesWithPath = entries.filter { !$0.dirPath.isEmpty }
            let groupedByFirst = Dictionary(grouping: entriesWithPath) { $0.dirPath[0] }
            
            // If this is a directory with no subdirs and ≤3 files, show it on one line
            if !fullPath.isEmpty && groupedByFirst.isEmpty && allFiles.count <= 3 {
                let path = fullPath.joined(separator: "/")
                if !allFiles.isEmpty {
                    lines.append("\(indent)\(path)/ -> \(allFiles.joined(separator: ", "))")
                }
                return lines
            }
            
            // Otherwise show normal tree structure
            if !allFiles.isEmpty {
                lines.append("\(indent)\(allFiles.joined(separator: ", "))")
            }
            
            for (dirname, subentries) in groupedByFirst.sorted(by: { $0.key < $1.key }) {
                lines.append("\(indent)\(dirname)/")
                
                // Remove first component of dirPath for recursive call
                let subentriesStripped = subentries.map { entry in
                    Entry(dirPath: Array(entry.dirPath.dropFirst()), 
                         leafChildNames: entry.leafChildNames)
                }
                
                lines.append(contentsOf: formatLevel(entries: subentriesStripped, 
                                                   indent: indent + "    ",
                                                   fullPath: fullPath + [dirname]))
            }
            
            return lines
        }
        
        return formatLevel(entries: entries, indent: "").joined(separator: "\n")
    }

    static func fromDir(url: URL) throws -> [Entry] {
        // First try git ls-files
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["ls-files", "--cached", "--others", "--exclude-standard"]
        process.currentDirectoryURL = url
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Only use git output if successful
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else {
                    throw NSError(domain: "FileTree", code: 1, 
                                userInfo: [NSLocalizedDescriptionKey: "Failed to decode git output"])
                }
                print("🟢 file_tree used git successfully")

                return try entriesFromPaths(files: output.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                    .sorted())
            }
        } catch {
            // Fall through to FileManager if git fails
            print("🟡 file_tree git error: \(error)")
        }
        print("🟡 file_tree failed to use git. Falling back to listing the FS.")

        // Fallback to FileManager
        return try recursivelyListFiles(at: url)
    }
    
    private static func recursivelyListFiles(at url: URL) throws -> [Entry] {
        let fileManager = FileManager.default
        var entries: [Entry] = []
        var currentDirPath: [String] = []
        var currentLeafNames: [String] = []
        
        // Get relative paths from base URL
        func relativePath(of fileURL: URL) -> String {
            return fileURL.path.replacingOccurrences(of: url.path + "/", with: "")
        }
        
        func processDirectory(_ dirURL: URL) throws {
            let contents = try fileManager.contentsOfDirectory(at: dirURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles])
            
            let sortedContents = contents.sorted { $0.path < $1.path }
            
            for itemURL in sortedContents {
                let isDirectory = try itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
                let relativePath = relativePath(of: itemURL)
                
                if isDirectory {
                    try processDirectory(itemURL)
                } else {
                    let components = relativePath.components(separatedBy: "/")
                    let dirPath = components.count > 1 ? Array(components.dropLast()) : []
                    let fileName = components.last!
                    
                    if dirPath != currentDirPath {
                        if !currentLeafNames.isEmpty {
                            entries.append(Entry(dirPath: currentDirPath, leafChildNames: currentLeafNames))
                        }
                        currentDirPath = dirPath
                        currentLeafNames = [fileName]
                    } else {
                        currentLeafNames.append(fileName)
                    }
                }
            }
        }
        
        try processDirectory(url)
        
        if !currentLeafNames.isEmpty {
            entries.append(Entry(dirPath: currentDirPath, leafChildNames: currentLeafNames))
        }
        
        return entries
    }
    
    private static func entriesFromPaths(files: [String]) throws -> [Entry] {
        var entries: [Entry] = []
        var currentDirPath: [String] = []
        var currentLeafNames: [String] = []
        
        let sortedFiles = files.sorted()
        for file in sortedFiles {
            let components = file.components(separatedBy: "/")
            let dirPath = components.count > 1 ? Array(components.dropLast()) : []
            let fileName = components.last!
            
            if dirPath != currentDirPath {
                if !currentLeafNames.isEmpty {
                    entries.append(Entry(dirPath: currentDirPath, leafChildNames: currentLeafNames))
                }
                currentDirPath = dirPath
                currentLeafNames = [fileName]
            } else {
                currentLeafNames.append(fileName)
            }
        }
        
        if !currentLeafNames.isEmpty {
            entries.append(Entry(dirPath: currentDirPath, leafChildNames: currentLeafNames))
        }
        
        return entries
    }
}

enum FileTree {
    static func fullTree(url: URL) -> String {
        chunksOfEntriesFromDir(url: url, entriesInChunk: 30).joined(separator: "\n")
    }

    static func chunksOfEntriesFromDir(url: URL, entriesInChunk: Int = 100) -> [String] {
        guard let entries = try? Entry.fromDir(url: url) else { return [] }

        var result: [String] = []
        var currentChunk: [Entry] = []
        var currentCount = 0

        for entry in entries {
            if currentCount + entry.leafChildNames.count > entriesInChunk && !currentChunk.isEmpty {
                result.append(Entry.formatAsString(entries: currentChunk))
                currentChunk = []
                currentCount = 0
            }

            currentChunk.append(entry)
            currentCount += entry.leafChildNames.count
        }

        if !currentChunk.isEmpty {
            result.append(Entry.formatAsString(entries: currentChunk))
        }

        return result
    }
}
