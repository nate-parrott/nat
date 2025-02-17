import AppKit
import SwiftUI
import ChatToys
import Foundation

struct ToolContext {
    var activeDirectory: URL?
    var log: @MainActor (UserVisibleLog) -> Void
    var document: Document?
    var autorun: @MainActor () -> Bool
}

protocol Tool {
    var functions: [LLMFunction] { get }

    // Check if this function comes from this tool and handle if so. Return nil (don't throw) if this function isn't handled by this tool.
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse?

    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String?
    func inlineContextUpdates(previous: String, context: ToolContext) async throws -> String?

    // Psuedo-functions are functions that we handle by parsing a standard (non tool call) response. They're valuable because wrapping new code in JSON
    func canHandlePsuedoFunction(fromPlaintext response: String) async throws -> Bool
    func handlePsuedoFunction(fromPlaintext response: String, context: ToolContext) async throws -> [ContextItem]?
}

// Default impls
extension Tool {
    var functions: [LLMFunction] { [] }

    // Check if this function comes from this tool and handle if so. Return nil (don't throw) if this function isn't handled by this tool.
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse? { nil }

    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String? { nil }
    func inlineContextUpdates(previous: String, context: ToolContext) async throws -> String? { nil }

    func canHandlePsuedoFunction(fromPlaintext response: String) async throws -> Bool { false }
    func handlePsuedoFunction(fromPlaintext response: String, context: ToolContext) async throws -> [ContextItem]? { nil }

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
        var path = path
        if path.starts(with: "/") {
            path = String(path.dropFirst()) // remove leading slash
        }
        guard let resolved = URL(string: path, relativeTo: URL(fileURLWithPath: activeDirectory.path(), isDirectory: true)) else {
            throw PathError.invalidPath
        }

        // Ensure resolved path is within active directory:
        var directoryStr = activeDirectory.absoluteString
        if !directoryStr.hasSuffix("/") {
            directoryStr += "/"
        }
        if !resolved.absoluteString.starts(with: directoryStr) {
            throw PathError.outsideWorkspace
        }

        return resolved
    }

    // Pass a block that takes a `dismiss` block and renders AnyView. The `dismiss` block lets you pass a result.
    @MainActor
    func presentUI<Result>(title: String, @ViewBuilder _ viewBlock: @MainActor @escaping (@escaping (Result) -> Void) -> AnyView) async throws -> Result {
        // HACK
        guard let baseVC = NSApplication.shared.mainWindow?.contentViewController ?? NSApplication.shared.windows.compactMap(\.contentViewController).last else {
            throw ToolUIError.noWindow
        }
        return await withCheckedContinuation { cont in
            DispatchQueue.main.async {
                let modalBox = Box<NSViewController>()
                let anyView = viewBlock {
                    if let modal = modalBox.value, document?.toolModalToPresent == modal {
                        document?.toolModalToPresent = nil
//                        baseVC.dismiss(modal)
                    }
                    cont.resume(returning: $0)
                }
                let modal = NSHostingController(rootView: anyView)
                modal.title = title
                modalBox.value = modal
                modal.view.frame = CGRect(x: 0, y: 0, width: 600, height: 500)
                if let document, document.toolModalToPresent == nil {
                    // HACK: Ensure we don't deallocate this modal before calling the callback, which would leak this continuation
                    document.toolModalToPresent = modal
                } else {
                    baseVC.presentAsSheet(modal)
                }
            }
        }
    }
}

class Box<T> {
    var value: T?
}

private enum ToolUIError: Error {
    case noWindow
}
