import Foundation
import SQLite3

// SQLite constants not automatically imported
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Detailed error types for CodeIndexDB operations
enum CodeIndexDBError: Error {
    case invalidParameter(name: String, reason: String)
    case databaseError(message: String)
    case sqliteError(code: Int32, message: String)
}

/// Actor that manages database operations for code indexing
actor CodeIndexDB {
    // MARK: - Types
    
    struct FileRecord: Equatable {
        let url: String
        let lastModified: Double
        let contentHash: String
        let readableAsText: Bool
        
        fileprivate func validate() throws {
            if url.isEmpty {
                throw CodeIndexDBError.invalidParameter(name: "url", reason: "URL cannot be empty")
            }
            if contentHash.isEmpty {
                throw CodeIndexDBError.invalidParameter(name: "contentHash", reason: "Content hash cannot be empty")
            }
            if lastModified < 0 {
                throw CodeIndexDBError.invalidParameter(name: "lastModified", reason: "Last modified time cannot be negative")
            }
        }
    }
    
    struct ChunkRecord: Equatable {
        let fileURL: String
        let content: String
        let embedding: Data
        
        fileprivate func validate() throws {
            if fileURL.isEmpty {
                throw CodeIndexDBError.invalidParameter(name: "fileURL", reason: "File URL cannot be empty")
            }
            if content.isEmpty {
                throw CodeIndexDBError.invalidParameter(name: "content", reason: "Content cannot be empty")
            }
            if embedding.isEmpty {
                throw CodeIndexDBError.invalidParameter(name: "embedding", reason: "Embedding cannot be empty")
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let dbPath: String
    private var db: OpaquePointer?
    
    // MARK: - Lifecycle
    
    init(path: String? = nil) throws {
        self.dbPath = path ?? "\(NSTemporaryDirectory())code_index.db"
        try openDatabase()
        try createTables()
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    // MARK: - Private Database Methods
    
    private func openDatabase() throws {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            throw CodeIndexDBError.databaseError(message: "Failed to open database")
        }
    }
    
    private func createTables() throws {
        let createFileTableSQL = """
            CREATE TABLE IF NOT EXISTS files (
                url TEXT PRIMARY KEY,
                last_modified REAL,
                content_hash TEXT,
                readable_as_text INTEGER
            );
        """
        
        let createChunkTableSQL = """
            CREATE TABLE IF NOT EXISTS chunks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                file_url TEXT,
                content TEXT,
                embedding BLOB,
                FOREIGN KEY(file_url) REFERENCES files(url) ON DELETE CASCADE
            );
        """
        
        try execute(sql: createFileTableSQL)
        try execute(sql: createChunkTableSQL)
    }
    
    private func execute(sql: String) throws {
        var errorMessage: String? = nil
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            errorMessage = String(cString: sqlite3_errmsg(db))
            throw CodeIndexDBError.sqliteError(code: sqlite3_errcode(db), message: errorMessage ?? "Unknown error")
        }
    }
    
    private func prepare(sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            throw CodeIndexDBError.sqliteError(code: sqlite3_errcode(db), 
                                             message: String(cString: sqlite3_errmsg(db)))
        }
        return statement
    }
    
    // MARK: - Public API
    
    func getAllFileURLs() async throws -> [String] {
        let sql = "SELECT url FROM files;"
        var urls: [String] = []
        
        guard let statement = try prepare(sql: sql) else {
            throw CodeIndexDBError.databaseError(message: "Failed to prepare statement")
        }
        defer { sqlite3_finalize(statement) }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let url = sqlite3_column_text(statement, 0) {
                urls.append(String(cString: url))
            }
        }
        
        return urls
    }
    
    func getFile(url: String) async throws -> FileRecord? {
        guard !url.isEmpty else {
            throw CodeIndexDBError.invalidParameter(name: "url", reason: "URL cannot be empty")
        }
        
        let sql = "SELECT last_modified, content_hash, readable_as_text FROM files WHERE url = ?;"
        guard let statement = try prepare(sql: sql) else {
            throw CodeIndexDBError.databaseError(message: "Failed to prepare statement")
        }
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, url, -1, SQLITE_TRANSIENT)
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return FileRecord(
                url: url,
                lastModified: sqlite3_column_double(statement, 0),
                contentHash: String(cString: sqlite3_column_text(statement, 1)),
                readableAsText: sqlite3_column_int(statement, 2) != 0
            )
        }
        
        return nil
    }
    
    func deleteFile(url: String) async throws {
        guard !url.isEmpty else {
            throw CodeIndexDBError.invalidParameter(name: "url", reason: "URL cannot be empty")
        }
        
        let sql = "DELETE FROM files WHERE url = ?;"
        guard let statement = try prepare(sql: sql) else {
            throw CodeIndexDBError.databaseError(message: "Failed to prepare statement")
        }
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, url, -1, SQLITE_TRANSIENT)
        
        if sqlite3_step(statement) != SQLITE_DONE {
            throw CodeIndexDBError.sqliteError(code: sqlite3_errcode(db), 
                                             message: String(cString: sqlite3_errmsg(db)))
        }
    }
    
    func upsertFile(_ file: FileRecord) async throws {
        try file.validate()
        
        let sql = """
            INSERT INTO files (url, last_modified, content_hash, readable_as_text)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(url) DO UPDATE SET
                last_modified = excluded.last_modified,
                content_hash = excluded.content_hash,
                readable_as_text = excluded.readable_as_text;
        """
        
        guard let statement = try prepare(sql: sql) else {
            throw CodeIndexDBError.databaseError(message: "Failed to prepare statement")
        }
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, file.url, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 2, file.lastModified)
        sqlite3_bind_text(statement, 3, file.contentHash, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 4, file.readableAsText ? 1 : 0)
        
        if sqlite3_step(statement) != SQLITE_DONE {
            throw CodeIndexDBError.sqliteError(code: sqlite3_errcode(db), 
                                             message: String(cString: sqlite3_errmsg(db)))
        }
    }
    
    func deleteChunks(forFileURL url: String) async throws {
        guard !url.isEmpty else {
            throw CodeIndexDBError.invalidParameter(name: "url", reason: "URL cannot be empty")
        }
        
        let sql = "DELETE FROM chunks WHERE file_url = ?;"
        guard let statement = try prepare(sql: sql) else {
            throw CodeIndexDBError.databaseError(message: "Failed to prepare statement")
        }
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, url, -1, SQLITE_TRANSIENT)
        
        if sqlite3_step(statement) != SQLITE_DONE {
            throw CodeIndexDBError.sqliteError(code: sqlite3_errcode(db), 
                                             message: String(cString: sqlite3_errmsg(db)))
        }
    }
    
    func insertChunk(_ chunk: ChunkRecord) async throws {
        try chunk.validate()
        
        let sql = "INSERT INTO chunks (file_url, content, embedding) VALUES (?, ?, ?);"
        guard let statement = try prepare(sql: sql) else {
            throw CodeIndexDBError.databaseError(message: "Failed to prepare statement")
        }
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, chunk.fileURL, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, chunk.content, -1, SQLITE_TRANSIENT)
        chunk.embedding.withUnsafeBytes { ptr in
            sqlite3_bind_blob(statement, 3, ptr.baseAddress, Int32(chunk.embedding.count), SQLITE_TRANSIENT)
        }
        
        if sqlite3_step(statement) != SQLITE_DONE {
            throw CodeIndexDBError.sqliteError(code: sqlite3_errcode(db), 
                                             message: String(cString: sqlite3_errmsg(db)))
        }
    }
}
