import Foundation

struct CodeChunker {
    static func chunk(content: String, fileURL: URL) -> [String] {
        let maxChunksPerFile = 10
        let tokenLimit = 3000
        let maxChunkSize = tokenLimit * 3 - 100 
        
        let lines = content.components(separatedBy: .newlines)
        var chunks: [String] = []
        var currentChunk: [String] = []
        var currentSize = 0
        var lineCount = 0
        
        func appendChunk() {
            if !currentChunk.isEmpty {
                chunks.append("File: \(fileURL.path)\n\n" + currentChunk.joined(separator: "\n"))
                currentChunk = []
                currentSize = 0
                lineCount = 0
            }
        }
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let shouldSplitOnSyntax = lineCount > 5 && (
                trimmed.starts(with: "struct ") ||
                trimmed.starts(with: "class ") ||
                trimmed.starts(with: "enum ") ||
                trimmed.starts(with: "func ") ||
                trimmed.starts(with: "function ") ||
                trimmed.starts(with: "interface ") ||
                trimmed.starts(with: "protocol ")
            )
            
            if shouldSplitOnSyntax {
                appendChunk()
            }
            
            currentChunk.append(line)
            currentSize += line.count + 1 // +1 for newline
            lineCount += 1
            
            if currentSize > maxChunkSize {
                appendChunk()
            }
        }
        
        appendChunk()
        
        if chunks.count > maxChunksPerFile {
            print("⚠️ Warning: File produced \(chunks.count) chunks, which exceeds maxChunksPerFile (\(maxChunksPerFile))")
        }
        
        return chunks
    }
}