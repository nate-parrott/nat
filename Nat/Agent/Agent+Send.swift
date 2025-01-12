import Foundation
import ChatToys

extension AgentThreadStore {
    func send(message: LLMMessage, tools: [Tool]) async throws {
        // Safely see if thread is idle, and set ourselves as in-progress:
        let alreadyRunning = await modifyThreadModel { state in
            if state.isTyping {
                return true
            }
            // Start modifying thread
            state.isTyping = true
            state.lastError = nil
            state.deleteIncompleteSteps()
            return false
        }
        if alreadyRunning {
            throw AgentError.alreadyRunning
        }

        // Generate completions:
        do {
            var step = ThreadModel.Step(id: UUID().uuidString, initialRequest: message, toolUseLoop: [])
            await modifyThreadModel { state in
                state.appendOrUpdate(step)
                state.isTyping = true
            }
            let llm = try LLMs.smartAgentModel()
            while true {
                // Loop and handle function calls
                let llmMessages = await readThreadModel().steps.flatMap(\.asLLMMessages)
                for try await partial in llm.completeStreaming(prompt: llmMessages, functions: []) {
                    step.appendOrUpdatePartialResponse(partial)
                    await modifyThreadModel { state in
                        state.appendOrUpdate(step)
                    }
                }
                if step.pendingFunctionCallsToExecute.count > 0 {
                    let fnResponses = try await self.handleFunctionCalls(step.pendingFunctionCallsToExecute)
                    step.toolUseLoop[step.toolUseLoop.count - 1].computerResponse = fnResponses
                    await modifyThreadModel { state in
                        state.appendOrUpdate(step)
                    }
                } else {
                    break // we're done!
                }
            }
        } catch {
            await modifyThreadModel { state in
                state.lastError = "Error: \(error)"
            }
            throw error
        }
        await modifyThreadModel { state in
            state.isTyping = false
        }
    }

    private func handleFunctionCalls(_ calls: [LLMMessage.FunctionCall]) async throws -> [LLMMessage.FunctionResponse] {
        fatalError("not implemented")
    }
}

enum AgentError: Error {
    case alreadyRunning
}

extension ThreadModel {
    mutating func appendOrUpdate(_ step: ThreadModel.Step) {
        if steps.last?.id == step.id {
            steps[steps.count - 1] = step
        } else {
            steps.append(step)
        }
    }

    mutating func deleteIncompleteSteps() {
        while let lastStep = steps.last, !lastStep.isComplete {
            steps.removeLast()
        }
    }

    var lastStep: Step? {
        get {
            steps.last
        }
        set {
            if let newValue {
                if steps.isEmpty {
                    steps.append(newValue)
                } else {
                    steps[steps.count - 1] = newValue
                }
            }
        }
    }
}

extension ThreadModel.Step {
    mutating func appendOrUpdatePartialResponse(_ response: LLMMessage) {
        if response.functionCalls.count > 0 {
            // This has function calls, so it's not the final assistant message
            assistantMessageForUser = nil
            if var lastToolUseStep = toolUseLoop.last, lastToolUseStep.computerResponse.isEmpty {
                // Update existing tool use step
                toolUseLoop[toolUseLoop.count - 1] = .init(initialResponse: response, computerResponse: [])
            } else {
                // Append to tool use step
                toolUseLoop.append(.init(initialResponse: response, computerResponse: []))
            }
        } else {
            // This is a plaintext response
            assistantMessageForUser = response
        }
    }

    var pendingFunctionCallsToExecute: [LLMMessage.FunctionCall] {
        if let step = toolUseLoop.last {
            if step.computerResponse.isEmpty {
                return [] // nothing pending
            } else {
                return step.initialResponse.functionCalls
            }
        }
        return []
    }
}
