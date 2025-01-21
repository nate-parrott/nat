//
//  Document.swift
//  Nat
//
//  Created by nate parrott on 1/5/25.
//

import Cocoa

enum DocumentMode: String, Equatable, Codable, CaseIterable {
    case agent
    case fast
    case codeSearch

    var displayName: String {
        switch self {
        case .agent:
            return "Agent"
        case .fast:
            return "Simple"
        case .codeSearch:
            return "Search"
        }
    }
}

struct DocumentState: Equatable, Codable {
    var thread: ThreadModel = .init()
    var folder: URL?
    var terminalVisible = false
    var mode = DocumentMode.agent
    var selectedFileInEditor: URL?
}

extension DocumentState {
    var selectedFileInEditorRelativeToFolder: String? {
        if let selectedFileInEditor, let folder {
            return selectedFileInEditor.asPathRelativeTo(base: folder)
        }
        return nil
    }
}

class Document: NSDocument {
    let store = DataStore(persistenceKey: nil, defaultModel: DocumentState(), queue: .main)

    override init() {
        super.init()
        // Add your subclass-specific initialization here.
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

    @MainActor
    func getOrCreateTerminal() -> ScriptableTerminalView {
        if let terminal {
            return terminal
        }
        terminal = ScriptableTerminalView(workingDir: store.model.folder ?? .homeDirectory)
        store.model.terminalVisible = true
        return terminal!
    }
}

