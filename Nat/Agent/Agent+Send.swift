import Foundation
import ChatToys

extension AgentThreadStore {
    @discardableResult func send(
        message: LLMMessage,
        llm: any FunctionCallingLLM,
        tools: [Tool],
        systemPrompt: String = "",
        agentName: String = "Agent",
        folderURL: URL?,
        maxIterations: Int = 20,
        finishFunction: LLMFunction? = nil // If provided, the model will return the finish-function's FunctionCall arg if the function is called
    ) async throws -> LLMMessage.FunctionCall? {
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

        let toolCtx = ToolContext(activeDirectory: folderURL)
        var allFunctions = tools.flatMap({ $0.functions })
        if let finishFunction {
            allFunctions.append(finishFunction)
        }

        // Generate completions:
        var finishResult: LLMMessage.FunctionCall?
        do {
            var step = ThreadModel.Step(id: UUID().uuidString, initialRequest: message, toolUseLoop: [])
            await modifyThreadModel { state in
                state.appendOrUpdate(step)
                state.isTyping = true
            }
            let llm = try LLMs.smartAgentModel()
            var i = 0
            while true {
                // Loop and handle function calls
                var llmMessages = await readThreadModel().steps.flatMap(\.asLLMMessages)
                if let systemPrompt = systemPrompt.nilIfEmpty {
                    llmMessages.insert(.init(role: .system, content: systemPrompt), at: 0)
                }
                for try await partial in llm.completeStreaming(prompt: llmMessages, functions: allFunctions) {
                    step.appendOrUpdatePartialResponse(partial)
                    await modifyThreadModel { state in
                        state.appendOrUpdate(step)
                    }
                }
                print("[\(agentName)] N functions: \(step.pendingFunctionCallsToExecute.count)")
                if step.pendingFunctionCallsToExecute.count > 0 {
                    if let finish = step.pendingFunctionCallsToExecute.first(where: { $0.name == finishFunction?.name }) {
                        finishResult = finish
                        break
                    }
                    let fnResponses = try await self.handleFunctionCalls(
                        step.pendingFunctionCallsToExecute,
                        tools: tools,
                        agentName: agentName,
                        toolCtx: toolCtx
                    )
                    step.toolUseLoop[step.toolUseLoop.count - 1].computerResponse = fnResponses
                    await modifyThreadModel { state in
                        state.appendOrUpdate(step)
                    }
                } else {
                    print("[\(agentName)] Received final response (no function calls)")
                    // expect assistantMessageForUser has been set by appendOrUpdatePartialResponse
                    break // we're done!
                }
                i += 1
                if i >= maxIterations {
                    print("[\(agentName) Ran too many iterations (\(i)) and timed out!")
                    if step.assistantMessageForUser == nil {
                        step.assistantMessageForUser = .init(role: .assistant, content: "[Agent timed out]")
                    }
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
        return finishResult
    }

    private func handleFunctionCalls(_ calls: [LLMMessage.FunctionCall], tools: [Tool], agentName: String, toolCtx: ToolContext) async throws -> [LLMMessage.FunctionResponse] {
        var responses = [LLMMessage.FunctionResponse]()
        for call in calls {
            print("[\(agentName)] Handling function call \(call.name)\((call.argumentsJson ?? ""))")
            let resp = try await handleFunctionCall(call, tools: tools, toolCtx: toolCtx)
            print("[Begin Response]\n\(resp.text.truncateTail(maxLen: 1000))\n[End Response]")
            responses.append(resp)
        }
        return responses
    }

    private func handleFunctionCall(_ call: LLMMessage.FunctionCall, tools: [Tool], toolCtx: ToolContext) async throws -> LLMMessage.FunctionResponse {
        for tool in tools {
            if let resp = try await tool.handleCallIfApplicable(call, context: toolCtx) {
                return resp
            }
        }
        throw AgentError.unknownToolName(call.name)
    }
}

enum AgentError: Error {
    case alreadyRunning
    case unknownToolName(String)
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
            if let lastToolUseStep = toolUseLoop.last, lastToolUseStep.computerResponse.isEmpty {
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
                return step.initialResponse.functionCalls
            } else {
                return []
            }
        }
        return []
    }
}
