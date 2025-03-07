import Foundation
import Combine

extension Document: AgentThreadStore {
    func readThreadModel() async -> ThreadModel {
        await store.readAsync().thread
    }

    func modifyThreadModel<ReturnVal>(_ callback: @escaping (inout ThreadModel) -> ReturnVal) async -> ReturnVal {
        await store.modifyAsync { state in
            return callback(&state.thread)
        }
    }

    func threadModelPublisher() -> AnyPublisher<ThreadModel, Never> {
        store.publisher.map(\.thread).eraseToAnyPublisher()
    }
}

extension Document {
    func pause() {
        store.modify { state in
            if case .running(let id) = state.thread.status {
                state.thread.status = .paused(id)
            }
        }
    }

    func unpause() {
        store.modify { state in
            if case .paused(let id) = state.thread.status {
                state.thread.status = .running(id) // causes checkCancelOrPause to finish
            }
        }
    }

    func stop() {
        // Cancel the current agent task
        currentAgentTask?.cancel()
        currentAgentTask = nil
        toolModalToPresent = nil

        // Reset typing state
        store.modify { state in
            state.thread.status = .none
        }
    }
    
    func clear() {
        stop()
        store.modify { state in
            state.thread = .init()
            state.terminalVisible = false
        }
        terminal = nil
    }
    
    /// Sends a message to the agent and handles the response
    func send(text: String, attachments: [ContextItem]) async {
        var msg = TaggedLLMMessage(role: .user, content: [.text(text)] + attachments)
        let folderURL = store.model.folder
        let curFile = store.model.selectedFileInEditorRelativeToFolder
        
        stop()

        if store.model.thread.steps.isEmpty {
            do {
                if let ctx = try await self.fetchProjectContext() {
                    msg.content.append(ctx)
                }
            } catch {
                Swift.print("Error feching initial context: \(error)")
            }
            
            // Generate title if this is the first message
            Task {
                try? await generateAndApplyAutoTitle(firstMessage: text)
            }
        } else {
            // This is a subsequent message
            do {
                if let updates = try await self.fetchUpdates() {
                    msg.content.append(updates)
                }
            }
            catch {
               Swift.print("Error feching updates: \(error)")
            }
        }
         
        currentAgentTask = Task {
            guard let llm = try? LLMs.smartAgentModel() else {
                await Alerts.showAppAlert(title: "No API Key", message: "Add your API key in Nat → Settings")
                return
            }
            do {
                let tools: [Tool] = [
                    FileReaderTool(), FileEditorTool(), CodeSearchTool(), FileTreeTool(),
                    TerminalTool(), WebResearchTool(), DeleteFileTool(), GrepTool(), ReadURLsTool(),
                    BasicContextTool(document: self, currentFilenameFromXcode: curFile),
                    DocsTool(document: self),
                    InspectTool(document: self),
//                    WebkitTool(),
                ]
                try await send(message: msg, llm: llm, document: self, tools: tools, folderURL: folderURL, maxIterations: store.model.maxIterations)
            } catch {
                if Task.isCancelled { return }
                // Do nothing (We already handle it)
            }
            if !Task.isCancelled {
                currentAgentTask = nil
            }
        }
    }
}
