import Combine
import SwiftUI
import Cocoa

class DocWindow: NSWindow {}

struct ContentViewWrapper: View {
    var document: Document?
    
    var body: some View {
        if let document = document {
            WithSnapshotMain(store: document.store, snapshot: { $0.cleaning }) { cleaning in
                if cleaning == true {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    mainContent
                }
            }
            .environment(\.document, document)
//            .overlay {
//                _FileEditorDemo()
//            }
        } else {
            Color.clear
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        WithSnapshotMain(store: document!.store, snapshot: { $0.mode }) { mode in
            switch mode {
            case .agent:
                ChatView()
            case .codeSearch:
                SearchView()
            case .docs:
                DocsView()
            }
        }
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
            modes.setImage(NSImage(systemSymbolName: mode.sfSymbolName, accessibilityDescription: mode.displayName), forSegment: i)
            modes.setLabel("", forSegment: i)
            modes.setToolTip(mode.displayName, forSegment: i)
        }
        modes.target = self
        modes.action = #selector(modeChanged(_:))
        modes.selectedSegment = DocumentMode.allCases.firstIndex(of: document!.store.model.mode)!

        // Setup folder button
        document!.store.publisher.map(\.folder).removeDuplicates().sink { [weak self] folderURL in
            guard let button = self?.folderButton else { return }
            if let folderURL {
                button.setTitleAndGlyph(folderURL.lastPathComponent, glyph: "folder")
            } else {
                button.setTitleAndGlyph("Choose...", glyph: "folder.badge.plus")
            }
        }.store(in: &subscriptions)
        folderButton!.target = self
        folderButton!.action = #selector(folderButtonPressed(_:))
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        document?.populateBasedOnXcode()
        // Written by Phil
        if let window = self.view.window {
            NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification, object: window)
                .sink { [weak self] _ in
                    self?.document?.populateBasedOnXcode()
                }
                .store(in: &subscriptions)
        }
    }

    @objc private func modeChanged(_ sender: AnyObject?) {
        document!.store.model.mode = DocumentMode.allCases[modeSegmentedControl!.indexOfSelectedItem]
    }

    @objc private func folderButtonPressed(_ sender: AnyObject?) {
        document?.pickFolder()
    }
    
    @IBAction func clearChat(_ sender: Any?) {
        document?.clear()
    }
    
    @IBAction func cleanThread(_ sender: Any?) {
        guard let document = document else { return }
        Task {
            try? await document.cleanThread()
        }
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

    func populateBasedOnXcode() {
//        if store.model.thread.steps.count > 0 || store.model.folder != nil {
//            return
//        }
        Task {
            do {
                let (project, file) = try await Scripting.xcodeState()
                let projDir = project?.deletingLastPathComponent().ancestorGitDir() ?? project?.deletingLastPathComponent()
                await store.modifyAsync { state in
                    if state.folder == nil {
                        state.folder = projDir
                    }
                    if let file, let projDir, file.asPathRelativeTo(base: projDir) != nil {
                        state.selectedFileInEditor = file
                    }
                }
            } catch {
                Swift.print("[populateBasedOnXcodeIfEmpty] Error: \(error)")
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
