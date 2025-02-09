import Foundation
import ChatToys
import CommonCrypto

actor CodeIndex {
    let projectURL: URL
    let indexDir: URL
    private let db: CodeIndexDB
    private var embeddingsLimit = 1000
    private var embeddingsPerformed = 0
    
    enum Status: Equatable, Codable {
        case none
        case indexing(needsIndexAgainAfter: Bool)
        case error(String)
    }
    private var status = Status.none
    private var blocksWaitingForIndexToFinish = [() -> Void]()
    
    init(projectURL: URL) throws {
        self.projectURL = projectURL
        
        // Create index dir using SHA256 hash of path
        let containerURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pathHash = SHA256.hash(string: projectURL.path)
        let indexDir = containerURL.appendingPathComponent("CodeIndex-\(pathHash)")
        self.indexDir = indexDir
        
        // Initialize database
        let dbPath = indexDir.appendingPathComponent("index.db").path
        let db: CodeIndexDB
        do {
            try FileManager.default.createDirectory(at: indexDir, withIntermediateDirectories: true)
            db = try CodeIndexDB(path: dbPath)
            print("[CodeIndex] Initialized for project at \(projectURL.path)")
        } catch {
            print("[CodeIndex] Failed to initialize DB: \(error). Using in-memory DB.")
            // Fallback to in-memory DB
            do {
                db = try CodeIndexDB()
            } catch {
                fatalError("Failed to create in-memory DB: \(error)")
            }
        }
        self.db = db
    }
    
    nonisolated func log(_ msg: String) {
        print("[CodeIndex] \(msg)")
    }
    
    func allTrackedFiles() async throws -> [URL] {
        try FileTree.allFileURLs(folder: projectURL)
    }
    
    func getEmbedder() throws -> Embedder {
        try LLMs.embedder(dims: 512)
    }
    
    func requestIndex(wait: Bool) async {
        if wait {
            await withCheckedContinuation { continuation in
                blocksWaitingForIndexToFinish.append {
                    continuation.resume()
                }
            }
        }
        
        switch status {
        case .none:
            status = .indexing(needsIndexAgainAfter: false)
            await _updateIndex()
            
            let blocks = blocksWaitingForIndexToFinish
            blocksWaitingForIndexToFinish = []
            blocks.forEach { $0() }
            
            status = .none
            
        case .indexing(let needsIndexAgainAfter):
            if !needsIndexAgainAfter {
                status = .indexing(needsIndexAgainAfter: true)
            }
            
        case .error:
            status = .indexing(needsIndexAgainAfter: false)
            await _updateIndex()
        }
    }
    
    private func _updateIndex() async {
        do {
            // Get all current files
            let files = try await allTrackedFiles()
            let fileURLs = Set(files.map { $0.path })
            
            // Get existing files from DB
            let existingFiles = try await db.getAllFileURLs()
            
            // Delete files that no longer exist
            for url in existingFiles {
                if !fileURLs.contains(url) {
                    try await db.deleteFile(url: url)
                }
            }
            
            // Process each file
            for fileURL in files {
                if embeddingsPerformed >= embeddingsLimit {
                    throw CodeIndexError.indexError("Embedding limit reached")
                }
                
                let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let modDate = (attrs[.modificationDate] as! Date).timeIntervalSince1970
                let contentHash = try SHA256.hash(data: Data(contentsOf: fileURL))
                
                // Check if file needs updating
                if let existing = try await db.getFile(url: fileURL.path),
                   existing.contentHash == contentHash,
                   existing.lastModified >= modDate {
                    continue // File hasn't changed
                }
                
                // Process file
                log("Processing \(fileURL.lastPathComponent)")
                var readableAsText = false
                
                if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                    readableAsText = true
                    let chunks = CodeChunker.chunk(content: content, fileURL: fileURL)
                    
                    // Delete old chunks
                    try await db.deleteChunks(forFileURL: fileURL.path)
                    
                    // Insert new chunks with embeddings
                    for chunk in chunks {
                        let embedding = try await getEmbedder().embed(documents: [chunk]).first!
                        let record = CodeIndexDB.ChunkRecord(
                            fileURL: fileURL.path,
                            content: chunk,
                            embedding: embedding.dataHalfPrecision
                        )
                        try await db.insertChunk(record)
                        
                        embeddingsPerformed += 1
                        if embeddingsPerformed >= embeddingsLimit {
                            break
                        }
                    }
                }
                
                // Update file record
                let record = CodeIndexDB.FileRecord(
                    url: fileURL.path,
                    lastModified: modDate,
                    contentHash: contentHash,
                    readableAsText: readableAsText
                )
                try await db.upsertFile(record)
            }
            
            log("Indexing complete")
            
        } catch {
            status = .error(error.localizedDescription)
            log("Error during indexing: \(error)")
        }
    }
    
    enum CodeIndexError: Error {
        case dbError(String)
        case indexError(String)
    }
}

// MARK: - SHA256 Helper

private struct SHA256 {
    static func hash(data: Data) throws -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    static func hash(string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        return (try? hash(data: data)) ?? ""
    }
}

// MARK: - Manager

actor CodeIndexManager {
    static let shared = CodeIndexManager()
    
    private var indicesByProjectURL = [URL: CodeIndex]()
    
    func getOrCreateIndex(forProjectURL url: URL) -> CodeIndex {
        if let existing = indicesByProjectURL[url] {
            return existing
        }
        let index = try! CodeIndex(projectURL: url) // This should be infallible
        indicesByProjectURL[url] = index
        return index
    }
}