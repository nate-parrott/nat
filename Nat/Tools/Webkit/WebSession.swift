import WebKit
import SwiftUI

@MainActor
class WebSession: NSObject, WKScriptMessageHandler {
    private var webView: WKWebView
    private var asyncCallbacks: [String: (Result<Any?, Error>) -> Void] = [:]
    private var nextCallbackId = 0
    private weak var document: Document?
    private var floatingPanel: SwiftUIFloatingPanel?
    
    init(document: Document) {
        self.document = document
        
        let config = WKWebViewConfiguration()
        let userController = WKUserContentController()
        config.userContentController = userController
        
        // Disable web security (as requested) using private API
        let preferences = config.preferences
        preferences.perform(Selector(("_setWebSecurityEnabled:")), with: false)
        
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 300, height: 300), configuration: config)
        super.init()
        
        self.webView.loadHTMLString("<html><body></body></html>", baseURL: URL(string: "https://example.com"))
        
        // Add message handlers
        userController.add(self, name: "replyToAsyncCall")
        userController.add(self, name: "sendMessageInChatOnBehalfOfUser")
        
        // Load blank page
        webView.load(URLRequest(url: URL(string: "about:blank")!))
    }
    
    // MARK: - JS Execution
    
    func evaluateJavaScript(_ script: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    func evaluateAsyncJavaScript(_ script: String) async throws -> Any? {
        let callbackId = String(nextCallbackId)
        nextCallbackId += 1
        
        let wrappedScript = """
        (function() {
            (async () => {
                try {
                    const result = await (\(script));
                    window.webkit.messageHandlers.replyToAsyncCall.postMessage({
                        id: "\(callbackId)",
                        success: true,
                        result: result
                    });
                } catch (error) {
                    window.webkit.messageHandlers.replyToAsyncCall.postMessage({
                        id: "\(callbackId)",
                        success: false,
                        error: error.toString()
                    });
                }
            })();
            return 'OK'
        })();
        """
        
        return try await withCheckedThrowingContinuation { continuation in
            asyncCallbacks[callbackId] = { result in
                continuation.resume(with: result)
            }
            
            webView.evaluateJavaScript(wrappedScript) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "replyToAsyncCall":
            guard let body = message.body as? [String: Any],
                  let callbackId = body["id"] as? String else { return }
            
            let callback = asyncCallbacks.removeValue(forKey: callbackId)
            
            if let success = body["success"] as? Bool, success {
                callback?(.success(body["result"]))
            } else {
                let error = (body["error"] as? String) ?? "Unknown error"
                callback?(.failure(NSError(domain: "WebSession", code: -1, userInfo: [NSLocalizedDescriptionKey: error])))
            }
            
            // TODO: The model needs to be told about this
        case "sendMessageInChatOnBehalfOfUser":
            guard let message = message.body as? String else { return }
            // TODO: Implement sending message to chat
//            print("TODO: Send message to chat:", message)
            Task {
                if await Alerts.showAppConfirmationDialog(title: "Send this message to Nat?", message: "'\(message)'", yesTitle: "Send", noTitle: "Don't Send") {
                    self.document?.stop()
                    await self.document?.send(text: message, attachments: [])
                }
            }
            
        default:
            break
        }
    }
    
    // MARK: - Presentation
    
    func present() {
        let container = WebViewContainer(webView: webView)
        if floatingPanel == nil {
            floatingPanel = SwiftUIFloatingPanel(view: AnyView(container))
        } else {
            floatingPanel?.hostedView = AnyView(container)
        }
        floatingPanel?.makeKeyAndOrderFront(nil)
    }
}

// SwiftUI wrapper for WKWebView
private struct WebViewContainer: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: Context) -> WKWebView {
        webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {}
}
