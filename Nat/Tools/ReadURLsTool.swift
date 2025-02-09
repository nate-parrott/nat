import Foundation
import ChatToys
import WebKit

struct ReadURLsTool: Tool {
    var functions: [LLMFunction] {
        [Self.fn.asLLMFunction]
    }
    
    static let fn = TypedFunction<Args>(name: "read_urls", description: "Fetches and returns the raw content of reference URLs. Only use when code comments or instructions explicitly identify reference URLs that should be viewed.", type: Args.self)
    
    struct Args: FunctionArgs {
        var urls: [String]
        
        static var schema: [String: LLMFunction.JsonSchema] {
            [
                "urls": .array(description: "List of URLs to fetch", itemType: .string(description: "URLs mentioned in code comments or instructions that should be fetched"))
            ]
        }
    }
    
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse? {
        if let args = Self.fn.checkMatch(call: call) {
            await context.log(.readUrls(args.urls))
            
            // Fetch URLs concurrently
            let results = await args.urls.concurrentMap { urlString in
                guard let url = URL(string: urlString) else {
                    return "Invalid URL: \(urlString)"
                }
                
                let fetcher = await PageContentFetcher(url: url)
                var lastContent: ContextItem.PageContent?
                
                do {
                    for try await content in try await fetcher.fetch() {
                        lastContent = content
                        if content.loadComplete {
                            break
                        }
                    }
                } catch {
                    return "Failed to fetch content from \(urlString): \(error)"
                }

                
                if let content = lastContent {
                    return "Content from \(urlString):\n\(content.text)"
                } else {
                    return "Failed to fetch content from \(urlString)"
                }
            }
            
            return call.response(text: results.joined(separator: "\n\n"))
        }
        return nil
    }
}
