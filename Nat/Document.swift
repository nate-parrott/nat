
//
//  Document.swift
//  Nat
//
//  Created by nate parrott on 1/5/25.
//

import Cocoa

enum DocumentMode: String, Equatable, Codable, CaseIterable {
    case agent
    case codeSearch
    case docs
    
    var displayName: String {
        switch self {
        case .agent:
            return "Agent"
        case .codeSearch:
            return "Search"
        case .docs:
            return "Docs"
        }
    }
    
    var sfSymbolName: String {
        switch self {
        case .agent:
            return "bubble"
        case .codeSearch:
            return "magnifyingglass"
        case .docs:
            return "questionmark.app"
        }
    }
}

struct DocumentState: Equatable, Codable {
    var thread: ThreadModel = .init()
    
    var folder: URL?
    var isWorktreeFromOriginalFolder: URL?
    var worktreeBranch: String?
    var inspectionDirectory: URL?
    
    var terminalVisible = false
    var mode = DocumentMode.agent
    var selectedFileInEditor: URL?
    var autorun = false
    var maxIterations = 20
    var dictating = false
    var cleaning: Bool?
}

extension DocumentState {
    var natDocsDir: URL? {
        folder?.appendingPathComponent("nat_docs", isDirectory: true)
    }
    
    var conversationCount: Int {
        var steps = self.thread.steps
        // Drop last incomplete message
        if steps.count > 0, !steps.last!.isComplete && thread.status.currentRunId != nil {
            steps.removeLast()
        }
        return steps.count
    }

    var selectedFileInEditorRelativeToFolder: String? {
        if let selectedFileInEditor, let folder {
            return selectedFileInEditor.asPathRelativeTo(base: folder)
        }
        return nil
    }
    
    var nFileSnippetsInInitialResponses: Int {
        thread.steps.filter { step in
            guard let firstLoop = step.toolUseLoop.first else { return false }
            return firstLoop.initialResponse.asPlainText.contains("%% BEGIN FILE SNIPPET")
        }.count
    }
}

class DocDataStore: DataStore<DocumentState> {
    override func processModelAfterLoad(model: inout DocumentState) {
        model.thread.status = .none
        model.inspectionDirectory = nil
    }
}

class Document: NSDocument {
    nonisolated let store = DocDataStore(persistenceKey: nil, defaultModel: DocumentState(), queue: .main)
    @Published var toolModalToPresent: NSViewController?

    override init() {
        super.init()
        // Add your subclass-specific initialization here.
        
        // Track down this pesky bug where file snippets end up in the initial response agent message (as if they came from the agent):
        store.addChangeHook { [weak self] oldState, newState in
            if newState.conversationCount != oldState.conversationCount {
                self?.updateChangeCount(.changeDone)
            }
        }
    }
    
    override func defaultDraftName() -> String {
        "Chat"
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
        (windowController.window!.contentViewController as! ViewController).document = self
        self.addWindowController(windowController)
    }

    override func data(ofType typeName: String) throws -> Data {
        try JSONEncoder().encode(store.model)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        try store.loadFromData(data)
    }

    // Current agent task that can be cancelled
    var currentAgentTask: Task<Void, Error>?
    
    var terminal: ScriptableTerminalView?
    var webSession: WebSession?

    @MainActor
    func getOrCreateTerminal() -> ScriptableTerminalView {
        if let terminal {
            return terminal
        }
        terminal = ScriptableTerminalView(workingDir: store.model.folder ?? .homeDirectory)
        store.model.terminalVisible = true
        return terminal!
    }
    
    @MainActor
    func getOrCreateWebSession() -> WebSession {
        if let webSession {
            return webSession
        }
        webSession = .init(document: self)
        return webSession!
    }
}
