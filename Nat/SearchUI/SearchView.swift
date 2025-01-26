import SwiftUI

struct SearchStats: Equatable {
    var timeElapsed: TimeInterval
    var filesRead: Int
    var agentsSpawned: Int
}

struct SearchView: View {
    @Environment(\.document) private var document: Document

    @State private var status = Status.none
    @State private var query = ""

    enum Status: Equatable {
        case none
        case loading
        case done(String, SearchStats)
        case error(String)
    }

    var body: some View {
        ScrollView {
            Form {
                TextField("Search", text: $query)
                    .onSubmit {
                        status = .loading
                        guard let folderURL = document.store.model.folder else { return }
                        Task {
                            do {
                                let ctx = ToolContext(activeDirectory: folderURL, log: {_ in () })
                                let searchResult = try await codeSearch2(queries: [query], folder: folderURL, context: ctx)
                                let results = searchResult.snippets.map { $0.asString(withLineNumbers: true) }.joined(separator: "\n\n")
                                status = .done(results, searchResult.stats)
                            } catch {
                                status = .error("\(error)")
                            }
                        }
                    }

                switch status {
                case .none:
                    EmptyView()
                case .loading:
                    Section {
                        Text("Loading...")
                    }
                case .done(let results, let stats):
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Time: \(String(format: "%.2f", stats.timeElapsed))s")
                                Text("•")
                                Text("\(stats.filesRead) files read")
                                Text("•")
                                Text("\(stats.agentsSpawned) agents spawned")
                            }
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            
                            Text(results)
                                .textSelection(.enabled)
                        }
                    }
                case .error(let error):
                    Section {
                        Text(error)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    func search(_ query: String) async throws -> String {
        guard let url = document.store.model.folder else {
            throw SearchError.generic("No folder found")
        }

        return FileTree.fullTree(url: url)
    }
}

private enum SearchError: Error {
    case generic(String)
}
