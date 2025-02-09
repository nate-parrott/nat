//import Foundation
//import ChatToys
//
//// Refer to https://github.com/nate-parrott/chattoys/blob/main/Sources/ChatToys/Embeddings/OpenAIEmbedder.swift
//// and https://github.com/nate-parrott/chattoys/blob/main/Sources/ChatToys/Embeddings/Embedding.swift
//
//actor CodeIndex {
//    func allTrackedFiles() -> [URL] {
//        // TODO: implement using git OR directory walk (less preferred) see ListFiles tool impl
//    }
//    
//    let projectURL: URL
//    let indexDir: URL // Persistent dir in app container, plus a hash of the project url
//    
//    enum Status: Equatable, Codable {
//        case none
//        case indexing(needsIndexAgainAfter: Bool)
//        case error(String)
//    }
//    
//    /*
//     TODO: use a sqlite database (create if needed) that:
//     - has a files tables that maps file URLs to the last-modified date and the hash of the last time their content was embedded
//     - has the chunks table
//     */
//    
//    init(projectURL: URL) {
//        // TODO: Use sqlite to store metadata, like the last-update date
//    }
//    
//    func updateIndex() async {
//        // TODO
//    }
//}
//
//actor CodeIndexManager {
//    static let shared = CodeIndexManager()
//    
//    private var indicesByProjectURL = [URL: CodeIndex]()
//    func getOrCreateIndex(forProjectURL url: URL) -> CodeIndex {
//        // TODO
//    }
//}
//
//extension String {
//    func chunkAsCode() -> String {
//        // Split a file into chunks according to these conditions:
//        // - Always split if adding a new line would make the current chunk more than token_limit * 3 - 100 chars
//        // - Split if there would be >5 lines and the line contains `struct`
//        // - Every chunk must contain
//        let tokenLimit = 3000
//    }
//}
