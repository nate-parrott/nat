import SwiftUI

struct SearchView: View {
    @Environment(\.document) private var document: Document

    @State private var status = Status.none
    @State private var query = ""

    enum Status: Equatable {
        case none
        case loading
        case done(String)
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
                                let results = try await codeSearch(prompt: query, folderURL: folderURL)
                                status = .done(results)
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
                case .done(let results):
                    Section {
                        Text(results)
                            .textSelection(.enabled)
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
