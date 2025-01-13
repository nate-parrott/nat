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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["ls-files", "--cached", "--others", "--exclude-standard"]
        process.currentDirectoryURL = url
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "FileTree", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode git output"])
        }
        
        var entries: [Entry] = []
        var currentDirPath: [String] = []
        var currentLeafNames: [String] = []
        
        let files = output.components(separatedBy: .newlines).filter { !$0.isEmpty }.sorted()
        
        for file in files {
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
