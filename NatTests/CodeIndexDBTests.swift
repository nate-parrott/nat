import XCTest
@testable import Nat

final class CodeIndexDBTests: XCTestCase {
    var db: CodeIndexDB!
    
    override func setUp() async throws {
        db = try CodeIndexDB() // Uses in-memory DB
    }
    
    override func tearDown() async throws {
        db = nil
    }
    
    func testFileOperations() async throws {
        let file = CodeIndexDB.FileRecord(
            url: "test.swift",
            lastModified: 12345.0,
            contentHash: "abc123",
            readableAsText: true
        )
        
        // Initial state
        let files = try await db.getAllFileURLs()
        XCTAssertTrue(files.isEmpty)
        
        // Insert
        try await db.upsertFile(file)
        let files2 = try await db.getAllFileURLs()
        XCTAssertEqual(files2, ["test.swift"])
        
        // Get
        let retrieved = try await db.getFile(url: "test.swift")
        XCTAssertEqual(retrieved?.url, file.url)
        XCTAssertEqual(retrieved?.lastModified, file.lastModified)
        XCTAssertEqual(retrieved?.contentHash, file.contentHash)
        XCTAssertEqual(retrieved?.readableAsText, file.readableAsText)
        
        // Update
        let updatedFile = CodeIndexDB.FileRecord(
            url: "test.swift",
            lastModified: 67890.0,
            contentHash: "def456",
            readableAsText: true
        )
        try await db.upsertFile(updatedFile)
        let retrieved2 = try await db.getFile(url: "test.swift")
        XCTAssertEqual(retrieved2?.lastModified, updatedFile.lastModified)
        XCTAssertEqual(retrieved2?.contentHash, updatedFile.contentHash)
        
        // Delete
        try await db.deleteFile(url: "test.swift")
        let files3 = try await db.getAllFileURLs()
        XCTAssertTrue(files3.isEmpty)
    }
    
    func testChunkOperations() async throws {
        // First create a file (due to foreign key constraint)
        let file = CodeIndexDB.FileRecord(
            url: "test.swift",
            lastModified: 12345.0,
            contentHash: "abc123",
            readableAsText: true
        )
        try await db.upsertFile(file)
        
        let chunk = CodeIndexDB.ChunkRecord(
            fileURL: "test.swift",
            content: "func test() {}",
            embedding: Data([1, 2, 3, 4])
        )
        
        // Insert
        try await db.insertChunk(chunk)
        
        // Delete chunks for file
        try await db.deleteChunks(forFileURL: "test.swift")
        
        // Delete file (should cascade delete chunks)
        try await db.deleteFile(url: "test.swift")
    }
}