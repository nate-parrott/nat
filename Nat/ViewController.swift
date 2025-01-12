import SwiftUI
import Cocoa

struct ContentViewWrapper: View {
    var document: Document?

    var body: some View {
        if let document = document {
            VStack(spacing: 0) {
                ChatView()
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
