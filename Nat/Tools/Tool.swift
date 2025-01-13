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

    // Psuedo-functions are functions that we handle by parsing a standard (non tool call) response. They're valuable because wrapping new code in JSON
    func handlePsuedoFunction(fromPlaintext response: String, context: ToolContext) async throws -> String?
}

// Default impls
extension Tool {
    var functions: [LLMFunction] { [] }

    // Check if this function comes from this tool and handle if so. Return nil (don't throw) if this function isn't handled by this tool.
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> LLMMessage.FunctionResponse? { nil }

    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String? { nil }
    func inlineContextUpdates(previous: String, context: ToolContext) async throws -> String? { nil }

    func handlePsuedoFunction(fromPlaintext response: String, context: ToolContext) async throws -> String? { nil }

}

enum Tools {
    static let forMainAgent: [any Tool] = []
}


// MARK: - Helpers

extension ToolContext {
    enum PathError: Error {
        case noActiveDirectory
        case outsideWorkspace
        case invalidPath
    }
    
    func resolvePath(_ path: String) throws -> URL {
        guard let activeDirectory else {
            throw PathError.noActiveDirectory
        }
        guard let resolved = URL(string: path, relativeTo: activeDirectory) else {
            throw PathError.invalidPath
        }
        var directoryStr = activeDirectory.absoluteString
        if !directoryStr.hasSuffix("/") {
            directoryStr += "/"
        }
        if directoryStr.starts(with: resolved.absoluteString) {
            throw PathError.outsideWorkspace
        }

        return resolved
    }
}

