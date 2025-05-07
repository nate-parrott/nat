import Foundation
import SwiftUI
import Combine

private struct FileResultsFetcher {
    let baseURL: URL
    
    @Environment(\.document) private var document
    
    func fetchAllFiles() throws -> [AttachmentSearchResult] {
        let allFiles = try FileTree.allFileURLs(folder: baseURL)
        
        return allFiles.compactMap { url in
            let filename = url.lastPathComponent
            if filename.hasPrefix(".") { return nil }
            guard let relativePath = url.asPathRelativeTo(base: baseURL) else {
                return nil
            }
            
            var enc = String.Encoding.utf8
            return AttachmentSearchResult(
                title: filename,
                subtitle: relativePath,
                icon: "doc",
                searchStrings: [filename, relativePath],
                getContextItem: {
                    return try .fileSnippet(FileSnippet(
                        content: document.store.model.stagedEdits?[url] ?? String(contentsOf: url, usedEncoding: &enc),
                        path: url,
                        projectRelativePath: relativePath,
                        lineStart: 0,
                        linesCount: 5000
                    ))
                }
            )
        }
    }
}

@MainActor
class AttachmentSearchProvider: ObservableObject {
    @Published private(set) var results: [AttachmentSearchResult] = []
    @Published var baseURL: URL? {
        didSet { refreshFilePool() }
    }
    
    private var currentQuery = CurrentValueSubject<String, Never>("")
    private var subscriptions = Set<AnyCancellable>()
    private var fetcher: FileResultsFetcher?
    private var filePool: [AttachmentSearchResult] = []
    
    init() {
        setupSearchPipeline()
    }
    
    private func refreshFilePool() {
        guard let baseURL = baseURL else {
            filePool = []
            return
        }
        
        fetcher = FileResultsFetcher(baseURL: baseURL)
        
        Task {
            do {
                filePool = try fetcher?.fetchAllFiles() ?? []
                // Re-run current search query to update results
                search(query: currentQuery.value)
            } catch {
                print("Error loading file pool: \(error)")
                filePool = []
            }
        }
    }
    
    private func filterResults(_ query: String) -> [AttachmentSearchResult] {
        if query == "" { return [] }
        let filtered = filePool.filter { $0.matches(query: query) }
        return Array(filtered.prefix(20))
    }
    
    private func setupSearchPipeline() {
        subscriptions.removeAll()
        
        currentQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.global(qos: .userInitiated))
            .map { [weak self] query -> [AttachmentSearchResult] in
                guard let self = self else { return [] }
                return self.filterResults(query)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] in self?.results = $0 })
            .store(in: &subscriptions)
    }
    
    func search(query: String) {
        currentQuery.send(query)
    }
}
