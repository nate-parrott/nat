import ChatToys
import Foundation

struct ToolContext {
    var activeDirectory: URL?
}

protocol Tool {
    var functions: [LLMFunction] { get }

    // Check if this function comes from this tool and handle if so. Return nil (don't throw) if this function isn't handled by this tool.
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> LLMMessage.FunctionResponse?

    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String?
    func inlineContextUpdates(previous: String, context: ToolContext) async throws -> String?
}

enum Tools {
    static let forMainAgent: [any Tool] = []
}
