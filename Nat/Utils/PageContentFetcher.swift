import ChatToys
import WebKit
import SwiftUI

@MainActor
class PageContentFetcher {
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
            Task { @MainActor in
                // Poll content every second for 5s or until complete
                var stepWhenLastStillLoading = 0
                let maxSteps = 20
                for step in 0...maxSteps {
                    // Check if navigation is complete
                    if webView.isLoading {
                        stepWhenLastStillLoading = step
                    }
                    
                    let complete = step > stepWhenLastStillLoading + 2 || step == 20
                    
                    // Get page text
                    if let text = try? await webView.markdown() {
                        let truncated = String(text.prefix(30_000))
                        if complete {
                            print("FETCHED: \(truncated)")
                        }
                        continuation.yield(ContextItem.PageContent(text: truncated, loadComplete: complete))
                    }
                    
                    if complete {
                        return
                    }
                    try await Task.sleep(for: .seconds(1))
                }
                
                continuation.finish()
            }
        }
    }
}
