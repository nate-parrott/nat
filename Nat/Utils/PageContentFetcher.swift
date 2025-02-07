import WebKit
import SwiftUI

actor PageContentFetcher {
    private let url: URL
    private let webView: WKWebView
    
    init(url: URL) {
        self.url = url
        self.webView = WKWebView(frame: .zero)
    }
    
    func fetch() async throws -> AsyncThrowingStream<ContextItem.PageContent, Error> {
        // Load the URL
        let request = URLRequest(url: url)
        webView.load(request)
        
        return AsyncThrowingStream { continuation in
            Task {
                let startTime = Date()
                
                // Poll content every second for 5s or until complete
                while true {
                    let timeElapsed = Date().timeIntervalSince(startTime)
                    if timeElapsed > 5 { break }
                    
                    // Check if navigation is complete
                    let complete = await webView.isLoading == false
                    
                    // Get page text
                    if let text = try? await webView.evaluateJavaScript("document.body.innerText") as? String {
                        let truncated = String(text.prefix(20000))
                        continuation.yield(ContextItem.PageContent(text: truncated, loadComplete: complete))
                    }
                    
                    if complete { break }
                    try await Task.sleep(for: .seconds(1))
                }
                
                continuation.finish()
            }
        }
    }
}