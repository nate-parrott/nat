//
//  Document.swift
//  Nat
//
//  Created by nate parrott on 1/5/25.
//

import Cocoa

struct DocumentState: Equatable, Codable {
    var thread: ThreadModel = .init()
    var folder: URL?
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


}

