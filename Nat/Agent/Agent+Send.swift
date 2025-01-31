import Foundation
import ChatToys

extension AgentThreadStore {
    @discardableResult func send(
        message: TaggedLLMMessage,
        llm: any FunctionCallingLLM,
        document: Document?,
        tools: [Tool],
        systemPrompt: String = Prompts.mainAgentPrompt,
        agentName: String = "Agent",
        folderURL: URL?,
        maxIterations: Int = 20,
        finishFunction: LLMFunction? = nil, // If provided, the model will return the finish-function's FunctionCall arg if the function is called
        fakeFunctions: Bool = LLMs.fakeFunctions // Use XML syntax for models that don't support function calling
    ) async throws -> LLMMessage.FunctionCall? {
        // Safely see if thread is idle, and set ourselves as in-progress:
        let alreadyRunning = await modifyThreadModel { state in
            if state.status == .paused || state.status == .running {
                return true
            }
            // Start modifying thread
            state.status = .running
            state.fixIncompleteSteps()
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
        var initialCtx = try await tools.asyncThrowingMap { tool in
            try await tool.contextToInsertAtBeginningOfThread(context: toolCtx)
        }.compactMap({ $0 })
        if let folderURL {
            initialCtx.append("The your tools' base directory is \(folderURL.absoluteString). When using tools to edit or read files, use paths RELATIVE to this. You cannot operate outside of this directory.")
        }
        var systemPrompt = systemPrompt.replacingOccurrences(of: "[[CONTEXT]]", with: initialCtx.joined(separator: "\n\n"))
        if fakeFunctions, allFunctions.count > 0 {
            systemPrompt = FakeFunctions.toolsToSystemPrompt(allFunctions) + "\n=======\n" + systemPrompt
        }
        let sysMsg = LLMMessage(role: .system, content: systemPrompt)

        // Generate completions:
        var finishResult: LLMMessage.FunctionCall?
        do {
            // Create a new 'step' to handle this message send and all resulting agent loops:
            var step = ThreadModel.Step(id: UUID().uuidString, initialRequest: message, toolUseLoop: [])
            await modifyThreadModel { state in
                state.appendOrUpdate(step)
            }
            func saveStep() async throws { // causes ui to update
                try await checkCancelOrPause()
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
                let taggedLLMMessages: [TaggedLLMMessage] = await readThreadModel().steps
                    .flatMap(\.asTaggedLLMMessages)
                    .asArray
                    .truncateTaggedLLMessages()
                    .byDroppingRedundantContext()
                var llmMessages = taggedLLMMessages.map { $0.asLLMMessage() }
                if fakeFunctions { llmMessages = llmMessages.map(\.byConvertingFunctionsToFakeFunctions) }
                if sysMsg.content.count > 0 {
                    llmMessages.insert(sysMsg, at: 0)
                }
                // If we're at the last step of the run, and there's a finish function, ONLY allow the finish function
                // TODO: implement this logic when using fake functions, which are passed as part of system prompt constructed above
                let allowedFns = i > 0 && i + 1 == maxIterations && finishFunction != nil ? [finishFunction!] : allFunctions
                for try await partial in llm.completeStreaming(prompt: llmMessages, functions: fakeFunctions ? [] : allowedFns) {
                    step.appendOrUpdatePartialResponse(partial.byConvertingFakeFunctionCallsToRealOnes)
                    try await saveStep()
                }
                print("[\(agentName)] Got response with \(step.pendingFunctionCallsToExecute.count) functions")

                // Use this new tool context to immediately grab logs and display 'em
                let childToolCtx = ToolContext(activeDirectory: folderURL, log: {
                    if step.toolUseLoop.count > 0 {
                        step.toolUseLoop[step.toolUseLoop.count - 1].userVisibleLogs.append($0)
                    } // HACK: where to put user visible logs if handling psuedo-fns?
                    Task {
                        try await saveStep()
                    }
                }, document: document)

                // If message has function calls, handle. In this case, we will have appended a new function loop step:
                if step.pendingFunctionCallsToExecute.count > 0 {
                    // Handle edge case where we get function calls AND psuedo-functions in the same response:
                    var prependToFirstFnResponse: [ContextItem]? = nil
                    if let psuedoFnResponse = try await handlePsuedoFunction(plaintextResponse: step.toolUseLoop.last?.initialResponse.asPlainText ?? "", agentName: agentName, tools: tools, toolCtx: childToolCtx) {
                        prependToFirstFnResponse = psuedoFnResponse
                    }

                    if let finish = step.pendingFunctionCallsToExecute.first(where: { $0.name == finishFunction?.name }) {
                        finishResult = finish
                        break
                    }
                    var fnResponses = try await self.handleFunctionCalls(
                        step.pendingFunctionCallsToExecute,
                        tools: tools,
                        agentName: agentName,
                        toolCtx: childToolCtx
                    )
                    // attach psuedo-fn response to ONE of the real fn responses, since we can't pass the result any other way.
                    if let prependToFirstFnResponse {
                        fnResponses[0].content += prependToFirstFnResponse
//                        fnResponses[0].text += "\n\n\(prependToFirstFnResponse)"
                    }
                    step.toolUseLoop[step.toolUseLoop.count - 1].computerResponse = fnResponses
//                    step.toolUseLoop[step.toolUseLoop.count - 1].userVisibleLogs += collectedLogs
                    collectedLogs.removeAll()
                    try await saveStep()
                }
                // If message has psuedo-functions only, handle those. In this case, we will have a final `assistantMessageForUser` set, but we want to remove it and make it into a step in the loop:
                else if let assistantMsg = step.assistantMessageForUser, let psuedoFnResponse = try await handlePsuedoFunction(plaintextResponse: assistantMsg.asPlainText, agentName: agentName, tools: tools, toolCtx: childToolCtx) {

                    // This is a psuedo-fn, so it's tool use too!
                    step.toolUseLoop.append(ThreadModel.Step.ToolUseStep(
                        initialResponse: assistantMsg,
                        computerResponse: [],
                        psuedoFunctionResponse: TaggedLLMMessage(role: .user, content: psuedoFnResponse), // LLMMessage(role: .user, content: psuedoFnResponse),
                        userVisibleLogs: collectedLogs
                    ))
                    collectedLogs.removeAll() // since we just added them
                    step.assistantMessageForUser = nil // Remove final assistant msg, since we handled this as a fn call.
                    try await saveStep()
                }
                // Handle response with no tools:
                else {
                    print("[\(agentName)] Received final response (no function calls): \(step.assistantMessageForUser?.asPlainText ?? "[None!!!]")")
                    // expect assistantMessageForUser has been set by appendOrUpdatePartialResponse
                    break // we're done!
                }
                i += 1
                if i >= maxIterations {
                    print("[\(agentName) Ran too many iterations (\(i)) and timed out!")
                    if step.assistantMessageForUser == nil {
                        step.assistantMessageForUser = TaggedLLMMessage(role: .assistant, content: [.text("[Agent timed out]")])
                    }
                }
                try await saveStep()
                try Task.checkCancellation()
            }
            try await saveStep()
        } catch {
            await modifyThreadModel { state in
                // Do not modify state if cancelled
                if (error as? CancellationError) == nil {
                    state.status = .none
                    // Do nothing (status should already be reset, and we may actually be in a new state)
//                    state.status = .stoppedWithError("\(error)")
                }
            }
            throw error
        }
        // Do not modify state if cancelled
        if !Task.isCancelled {
            await modifyThreadModel { state in
                // If not in error state, set state to none
                if state.status == .running {
                    state.status = .none
                }
            }
        }
        return finishResult
    }

    private func handlePsuedoFunction(plaintextResponse: String?, agentName: String, tools: [Tool], toolCtx: ToolContext) async throws -> [ContextItem]? {
        guard let plaintextResponse else { return nil }
        for tool in tools {
            if let resp = try await tool.handlePsuedoFunction(fromPlaintext: plaintextResponse, context: toolCtx) {
                return resp
            }
        }
        return nil
    }

    private func handleFunctionCalls(_ calls: [LLMMessage.FunctionCall], tools: [Tool], agentName: String, toolCtx: ToolContext) async throws -> [TaggedLLMMessage.FunctionResponse] {
        var responses = [TaggedLLMMessage.FunctionResponse]()
        for call in calls {
            print("[\(agentName)] Handling function call \(call.name)\((call.argumentsJson ?? ""))")
            let resp = try await handleFunctionCall(call, tools: tools, toolCtx: toolCtx)
            print("[Begin Response]\n\(resp.asLLMResponse.text.truncateTail(maxLen: 1000))\n[End Response]")
            responses.append(resp)
        }
        return responses
    }

    private func handleFunctionCall(_ call: LLMMessage.FunctionCall, tools: [Tool], toolCtx: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse {
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

    mutating func fixIncompleteSteps() {
        if steps.count > 0 {
            steps[steps.count - 1].fixIfIncomplete()
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
    mutating func fixIfIncomplete() {
        if isComplete { return }
        if toolUseLoop.count > 0 {
            toolUseLoop[toolUseLoop.count - 1].fixIfIncomplete()
        }
        if assistantMessageForUser == nil {
            assistantMessageForUser = .init(role: .assistant, content: [.text("[Response was interrupted]")])
        }
    }

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
            assistantMessageForUser = TaggedLLMMessage(message: response)
        }
    }

    var pendingFunctionCallsToExecute: [LLMMessage.FunctionCall] {
        if let step = toolUseLoop.last, !step.isComplete {
            return step.initialResponse.functionCalls
        }
        return []
    }
}

extension ThreadModel.Step.ToolUseStep {
    mutating func fixIfIncomplete() {
        if isComplete { return }
        if initialResponse.functionCalls.count > 0 {
            computerResponse = initialResponse.functionCalls.map({ call in
                return call.response(text: "[Response was interrupted]")
            })
        } else {
            psuedoFunctionResponse = .init(role: .user, content: [.text("[Response was interrupted]")])
        }
    }
}
