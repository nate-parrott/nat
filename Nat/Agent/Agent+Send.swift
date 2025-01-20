import Foundation
import ChatToys

extension AgentThreadStore {
    @discardableResult func send(
        message: LLMMessage,
        llm: any FunctionCallingLLM,
        document: Document?,
        tools: [Tool],
        systemPrompt: String = Prompts.mainAgentPrompt,
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

        var allFunctions = tools.flatMap({ $0.functions })
        if let finishFunction {
            allFunctions.append(finishFunction)
        }
        
        var collectedLogs = [UserVisibleLog]()
        let toolCtx = ToolContext(activeDirectory: folderURL, log: { collectedLogs.append($0) }, document: document)

        assert(systemPrompt.contains("[[CONTEXT]]"), "[\(agentName)] system prompt must have a [[CONTEXT]] token.")
        let initialCtx = try await tools.asyncThrowingMap { tool in
            try await tool.contextToInsertAtBeginningOfThread(context: toolCtx)
        }.compactMap({ $0 }).joined(separator: "\n\n")
        let sysMsg = LLMMessage(role: .system, content: systemPrompt.replacingOccurrences(of: "[[CONTEXT]]", with: initialCtx))

        // Generate completions:
        var finishResult: LLMMessage.FunctionCall?
        do {
            // Create a new 'step' to handle this message send and all resulting agent loops:
            var step = ThreadModel.Step(id: UUID().uuidString, initialRequest: TaggedLLMMessage(message: message), toolUseLoop: [])
            await modifyThreadModel { state in
                state.appendOrUpdate(step)
                state.isTyping = true
            }
            func saveStep() async { // causes ui to update
                if Task.isCancelled { return }
                await modifyThreadModel { state in
                    state.appendOrUpdate(step)
                }
            }

            var llm = try LLMs.smartAgentModel()
            llm.reportUsage = { usage in
                print("[💰 Usage]: \(usage.prompt_tokens) prompt, \(usage.completion_tokens) completion for model \(llm.options.model.name)")
                collectedLogs.append(.tokenUsage(prompt: usage.prompt_tokens, completion: usage.completion_tokens, model: llm.options.model.name))
            }
            var i = 0
            while true {
                // Loop and handle function calls
                var llmMessages = await readThreadModel().steps.flatMap(\.asLLMMessages)
                if sysMsg.content.count > 0 {
                    llmMessages.insert(sysMsg, at: 0)
                }
                // If we're at the last step of the run, and there's a finish function, ONLY allow the finish function
                let allowedFns = i > 0 && i + 1 == maxIterations && finishFunction != nil ? [finishFunction!] : allFunctions
                for try await partial in llm.completeStreaming(prompt: llmMessages, functions: allowedFns) {
                    step.appendOrUpdatePartialResponse(partial)
                    await saveStep()
                }
                print("[\(agentName)] Got response with \(step.pendingFunctionCallsToExecute.count) functions")

                // If message has function calls, handle. In this case, we will have appended a new function loop step:
                if step.pendingFunctionCallsToExecute.count > 0 {
                    // Handle edge case where we get function calls AND psuedo-functions in the same response:
                    var prependToFirstFnResponse: String? = nil
                    if let psuedoFnResponse = try await handlePsuedoFunction(plaintextResponse: step.toolUseLoop.last?.initialResponse.asPlainText ?? "", agentName: agentName, tools: tools, toolCtx: toolCtx) {
                        prependToFirstFnResponse = psuedoFnResponse
                    }

                    if let finish = step.pendingFunctionCallsToExecute.first(where: { $0.name == finishFunction?.name }) {
                        finishResult = finish
                        break
                    }
                    // Use this new tool context to immediately grab logs and display 'em
                    let childToolCtx = ToolContext(activeDirectory: folderURL, log: {
                        step.toolUseLoop[step.toolUseLoop.count - 1].userVisibleLogs.append($0)
                        Task {
                            await saveStep()
                        }
                    }, document: document)
                    var fnResponses = try await self.handleFunctionCalls(
                        step.pendingFunctionCallsToExecute,
                        tools: tools,
                        agentName: agentName,
                        toolCtx: childToolCtx
                    )
                    // attach psuedo-fn response to ONE of the real fn responses, since we can't pass the result any other way.
                    if let prependToFirstFnResponse {
                        fnResponses[0].text += "\n\n\(prependToFirstFnResponse)"
                    }
                    step.toolUseLoop[step.toolUseLoop.count - 1].computerResponse = fnResponses
//                    step.toolUseLoop[step.toolUseLoop.count - 1].userVisibleLogs += collectedLogs
                    collectedLogs.removeAll()
                    await saveStep()
                }
                // If message has psuedo-functions only, handle those. In this case, we will have a final `assistantMessageForUser` set, but we want to remove it and make it into a step in the loop:
                else if let assistantMsg = step.assistantMessageForUser, let psuedoFnResponse = try await handlePsuedoFunction(plaintextResponse: assistantMsg.content, agentName: agentName, tools: tools, toolCtx: toolCtx) {

                    // This is a psuedo-fn, so it's tool use too!
                    step.toolUseLoop.append(ThreadModel.Step.ToolUseStep(
                        initialResponse: TaggedLLMMessage(message: assistantMsg),
                        computerResponse: [],
                        psuedoFunctionResponse: LLMMessage(role: .user, content: psuedoFnResponse),
                        userVisibleLogs: collectedLogs
                    ))
                    collectedLogs.removeAll() // since we just added them
                    step.assistantMessageForUser = nil // Remove final assistant msg, since we handled this as a fn call.
                    await saveStep()
                }
                // Handle response with no tools:
                else {
                    print("[\(agentName)] Received final response (no function calls): \(step.assistantMessageForUser?.content ?? "[None!!!]")")
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
                await saveStep()
            }
            await saveStep()
        } catch {
            await modifyThreadModel { state in
                state.lastError = "Error: \(error)"
                state.isTyping = false
            }
            throw error
        }
        await modifyThreadModel { state in
            state.isTyping = false
        }
        return finishResult
    }

    private func handlePsuedoFunction(plaintextResponse: String?, agentName: String, tools: [Tool], toolCtx: ToolContext) async throws -> String? {
        guard let plaintextResponse else { return nil }
        for tool in tools {
            if let resp = try await tool.handlePsuedoFunction(fromPlaintext: plaintextResponse, context: toolCtx) {
                return resp
            }
        }
        return nil
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
                toolUseLoop[toolUseLoop.count - 1] = .init(initialResponse: TaggedLLMMessage(message: response), computerResponse: [])
            } else {
                // Append to tool use step
                toolUseLoop.append(.init(initialResponse: TaggedLLMMessage(message: response), computerResponse: []))
            }
        } else {
            // This is a plaintext response
            assistantMessageForUser = response
        }
    }

    var pendingFunctionCallsToExecute: [LLMMessage.FunctionCall] {
        if let step = toolUseLoop.last, !step.isComplete {
            return step.initialResponse.functionCalls
        }
        return []
    }
}
