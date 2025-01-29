import SwiftUI
import AppKit

struct DocsEditor: NSViewRepresentable {
    @ObservedObject var fileSaver: DebouncedFileSaver
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollablePlainDocumentContentTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.string = fileSaver.content
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        if textView.string != fileSaver.content {
            textView.string = fileSaver.content
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(fileSaver: fileSaver)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var fileSaver: DebouncedFileSaver
        
        init(fileSaver: DebouncedFileSaver) {
            self.fileSaver = fileSaver
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            fileSaver.content = textView.string
        }

        // We need to provide our own undo mgr to avoid propagating undos to the document level and triggering "Edited" UI on the window
        let undoMgr = UndoManager()
        func undoManager(for view: NSTextView) -> UndoManager? {
            undoMgr
        }
    }
}


