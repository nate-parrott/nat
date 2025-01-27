import SwiftUI
import AppKit
import Combine

enum TextFieldEvent {
    enum Key: Equatable {
        case enter
        case upArrow
        case downArrow
    }

    case key(Key)
    case focus
    case blur
    case paste(String)
}

struct InputTextFieldOptions: Equatable {
    var placeholder: String
    var font: NSFont = NSFont.systemFont(ofSize: 14)
    var color: NSColor = NSColor.textColor
    var insets = CGSize(width: 0, height: 0)
    var placeholderColor: NSColor? = nil

    var effectivePlaceholderColor: NSColor {
        return placeholderColor ?? color.withAlphaComponentSafe(0.5)
    }

    var attributedPlaceholder: NSAttributedString {
        return NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: effectivePlaceholderColor,
            .font: font
        ])
    }
}

struct InputTextField: NSViewRepresentable {
    @Binding var text: String
    var options: InputTextFieldOptions
    var focusDate: Date?
    var onEvent: (TextFieldEvent) -> Void
    var contentSize: Binding<CGSize>?

    func makeNSView(context: Context) -> _InputTextFieldView { _InputTextFieldView() }

    func updateNSView(_ nsView: _InputTextFieldView, context: Context) {
        nsView.text = $text
        nsView.options = options
        nsView.onEvent = onEvent
        nsView.focusDate = focusDate
        nsView.contentSize = contentSize
    }
}


class _InputTextFieldView: NSView, NSTextViewDelegate {
    var onEvent: ((TextFieldEvent) -> Void)?
    var text = Binding<String>(get: { "" }, set: { _ in }) {
        didSet {
            if text.wrappedValue != textView.string {
                textView.string = text.wrappedValue
                contentSizeMayHaveChanged()
            }
        }
    }
    var focusDate: Date? {
        didSet {
            if focusDate != oldValue {
                if focusDate != nil {
                    window?.makeFirstResponder(textView)
                } else {
                    window?.makeFirstResponder(nil)
                }
            }
        }
    }
    var contentSize: Binding<CGSize>? {
        didSet {
            DispatchQueue.main.async {
                self.contentSizeMayHaveChanged()
            }
        }
    }

    // multi-line scrolling nstextview
    private let scrollView = NSTextView.scrollablePlainDocumentContentTextView()
    private var textView: NSTextView { scrollView.documentView as! NSTextView }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.hasVerticalScroller = false
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: NSText.didChangeNotification, object: textView)
//        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
    }

    var options: InputTextFieldOptions = InputTextFieldOptions(placeholder: "") {
        didSet {
            guard options != oldValue else { return }
            // update:
            textView.font = options.font
            textView.textColor = options.color
            textView.insertionPointColor = options.color
            textView.setValue(options.attributedPlaceholder, forKey: "placeholderAttributedString")
            textView.textContainerInset = options.insets
            contentSizeMayHaveChanged()
        }
    }

    // override did move to windwo and focus if necessary

    private var focusSubscriptions = Set<AnyCancellable>()
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        focusSubscriptions.removeAll()
        guard let window else { return }

        if focusDate != nil {
            window.makeFirstResponder(textView)
        }

        // KVO the window's first responder to see if it's us
        window.publisher(for: \.firstResponder).sink { [weak self] firstResponder in
            guard let self else { return }
            if firstResponder === self.textView {
                self.onEvent?(.focus)
            } else {
                self.onEvent?(.blur)
            }
        }.store(in: &focusSubscriptions)

        contentSizeMayHaveChanged()
    }

    private func contentSizeMayHaveChanged() {
        if let textContainer = self.textView.textContainer, let layoutMgr = self.textView.layoutManager {
            let takenSize = layoutMgr.usedRect(for: textContainer).size
            let minHeight = options.font.pointSize
            let size = CGSize(
                width: takenSize.width + options.insets.width * 2,
                height: max(takenSize.height, minHeight) + options.insets.height * 2
            )
            if let contentSize, contentSize.wrappedValue != size {
                contentSize.wrappedValue = size
            }
        }
//        DispatchQueue.main.async {
//            // HACK
//            if let textContainer = self.textView.textContainer, let layoutMgr = self.textView.layoutManager {
//                self.contentSize = layoutMgr.usedRect(for: textContainer).size
//            }
//        }
    }

    // MARK: - NSTextViewDelegate

    func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString text: String?) -> Bool {
        // Intercept long pastes from clipboard
        if let text = text, text.count > 500 {
            // Only check pasteboard for large text to avoid unnecessary slowdown
            if let pb = NSPasteboard.general.string(forType: .string), text == pb {
                onEvent?(.paste(text))
                return false
            }
        }
        return true
    }
    
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            // If shift is pressed, insert newline, otherwise send event
            if NSEvent.modifierFlags.contains(.shift) {
                return false
            } else {
                onEvent?(.key(.enter))
                contentSizeMayHaveChanged()
                return true
            }
        case #selector(NSResponder.moveUp(_:)):
            onEvent?(.key(.upArrow))
            return true
        case #selector(NSResponder.moveDown(_:)):
            onEvent?(.key(.downArrow))
            return true
        default:
            return false
        }
    }

    func textDidChange(_ notification: Notification) {
        text.wrappedValue = textView.string
        contentSizeMayHaveChanged()
    }

    override var mouseDownCanMoveWindow: Bool { true }
}
