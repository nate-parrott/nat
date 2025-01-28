import Foundation
import Combine

class DebouncedFileSaver: ObservableObject {
    @Published var content: String = ""
    private var fileURL: URL
    private var subscription: AnyCancellable?
    private var lastSavedContent: String = ""
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        // Load initial content
        self.content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        self.lastSavedContent = self.content
        
        // Setup debounced save
        subscription = $content
            .debounce(for: .seconds(5), scheduler: DispatchQueue.main)
            .sink { [weak self] newContent in
                self?.save(content: newContent)
            }
    }
    
    func save(content: String) {
        guard content != lastSavedContent else { return }
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            lastSavedContent = content
        } catch {
            print("Error saving file: \(error)")
        }
    }
    
    func saveIfNeeded() {
        save(content: content)
    }
    
    deinit {
        saveIfNeeded()
    }
}
