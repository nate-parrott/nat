import Combine
import SwiftUI
import Cocoa

struct ContentViewWrapper: View {
    var document: Document?

    var body: some View {
        if let document = document {
            WithSnapshotMain(store: document.store, snapshot: { $0.mode }) { mode in
                switch mode {
                case .agent:
                    ChatView()
                        .overlay {
                            ChatEmptyState()
                        }
                case .codeSearch:
                    SearchView()
                case .fast:
                    Text("Fast")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .environment(\.document, document)
        } else {
            Color.clear
        }
    }
}

struct ContentView: View {
    @Environment(\.document) var document: Document

    var body: some View {
        Text("hi!")
    }
}

class ViewController: NSViewController {
    private var subscriptions = Set<AnyCancellable>()

    var modeSegmentedControl: NSSegmentedControl? {
        view.window?.toolbar?.items.first(where: { $0.itemIdentifier.rawValue == "Mode" })?.view as? NSSegmentedControl
    }

    var folderButton: NSButton? {
        view.window?.toolbar?.items.first(where: { $0.itemIdentifier.rawValue == "Folder" })?.view as? NSButton
    }

    var document: Document? {
        get {
            return rootVC.rootView.document
        }
        set {
            rootVC.rootView.document = newValue
        }
    }

    let rootVC = NSHostingController(rootView: ContentViewWrapper())

    override func viewDidLoad() {
        super.viewDidLoad()
        // Add the rootVC to the view
        addChild(rootVC)
        rootVC.sizingOptions = []
        view.addSubview(rootVC.view)
        rootVC.view.frame = view.bounds
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        rootVC.view.frame = view.bounds
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        // Setup mode picker
        let modes = modeSegmentedControl!
        modes.segmentCount = DocumentMode.allCases.count
        for (i, mode) in DocumentMode.allCases.enumerated() {
            modes.setLabel(mode.displayName, forSegment: i)
        }
        modes.target = self
        modes.action = #selector(modeChanged(_:))
        modes.selectedSegment = DocumentMode.allCases.firstIndex(of: document!.store.model.mode)!

        // Setup folder button
        document!.store.publisher.map(\.folder).removeDuplicates().sink { [weak self] folderURL in
            guard let button = self?.folderButton else { return }
            if let folderURL {
                button.title = folderURL.lastPathComponent
            } else {
                button.title = "Choose Folder..."
            }
        }.store(in: &subscriptions)
        folderButton!.target = self
        folderButton!.action = #selector(folderButtonPressed(_:))
    }

    @objc private func modeChanged(_ sender: AnyObject?) {
        document!.store.model.mode = DocumentMode.allCases[modeSegmentedControl!.indexOfSelectedItem]
    }

    @objc private func folderButtonPressed(_ sender: AnyObject?) {
        document?.pickFolder()
    }
}

extension Document {
    func pickFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false

        openPanel.begin { [weak self] result in
            if result == .OK, let url = openPanel.url {
                // Update the document's folder with the selected URL
                self?.store.model.folder = url
            }
        }
    }
}

struct DocumentKey: EnvironmentKey {
    static let defaultValue: Document = Document()
}

extension EnvironmentValues {
    var document: Document {
        get { self[DocumentKey.self] }
        set { self[DocumentKey.self] = newValue }
    }
}
