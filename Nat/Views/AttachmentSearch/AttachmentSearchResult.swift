import Foundation

struct AttachmentSearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let searchStrings: [String]
    let getContextItem: () async throws -> ContextItem
    
    func matches(query: String) -> Bool {
        let query = query.lowercased()
        return searchStrings.contains { $0.lowercased().hasPrefix(query) }
    }
}

// Since we removed Hashable, we need a way to identify selected items
extension AttachmentSearchResult: Hashable {
    static func == (lhs: AttachmentSearchResult, rhs: AttachmentSearchResult) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}