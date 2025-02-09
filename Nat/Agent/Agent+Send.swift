import SwiftUI
import Foundation
import ChatToys

private struct AgentInfo {
    var name: String
    var folder: URL?
    var tools: [Tool]
    var document: Document?
    var autorun: @MainActor () -> Bool
}

extension AgentThreadStore {
    @MainActor
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
        let runId = UUID()
        let alreadyRunning = await modifyThreadModel { state in
            switch state.status {
            case .running, .paused: return true
            case .stoppedWithError, .none:
                // Ready to start
                // Start modifying thread
                state.status = .running(runId)
                state.fixIncompleteSteps()
                return false
            }
        }
        if alreadyRunning {
            throw AgentError.alreadyRunning
        }
        
        func modifyThreadModelIfRunIdStillMatches(_ block: @escaping (inout ThreadModel) -> Void) async {
            await modifyThreadModel { model in
                if model.status.currentRunId == runId {
                    block(&model)
                }
            }
        }
        
        let info = AgentInfo(name: agentName, folder: folderURL, tools: tools, document: document, autorun: { document?.store.model.autorun ?? false })

        var allFunctions = tools.flatMap({ $0.functions })
        if let finishFunction {
            allFunctions.append(finishFunction)
        }
        
//        var collectedLogs = [UserVisibleLog]()
        let toolCtx = ToolContext(activeDirectory: folderURL, log: { _ in () }, document: document, autorun: { false })
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
                await modifyThreadModelIfRunIdStillMatches { state in
                    state.appendOrUpdate(step)
                }
            }

            var llm = try LLMs.smartAgentModel()
            llm.reportUsage = { usage in
                print("[💰 Usage]: \(usage.prompt_tokens) prompt, \(usage.completion_tokens) completion for model \(llm.options.model.name)")
            }
            var i = 0
            while true {
                // Loop and handle function calls
                let taggedLLMMessages: [TaggedLLMMessage] = await readThreadModel().steps
                    .flatMap(\.asTaggedLLMMessages)
                    .asArray
                    .truncateOldMessages()
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

                if let finish = step.pendingFunctionCallsToExecute.first(where: { $0.name == finishFunction?.name }) {
                    finishResult = finish
                    break
                }
                
                try Task.checkCancellation()
                
                // CALL
                let shouldContinue = try await handleFunctionCalls(agent: info, step: .init(get: { step }, set: {
                    step = $0
                    Task {
                        try? await saveStep()
                    }
                }))
                if !shouldContinue {
                    break
                }
                i += 1
                if i >= maxIterations {
                    print("[\(agentName) Ran too many iterations (\(i)) and timed out!")
                    if step.assistantMessageForUser == nil {
                        step.assistantMessageForUser = TaggedLLMMessage(role: .assistant, content: [.text("[Agent timed out]")])
                    }
                    break
                }
                try await saveStep()
                try Task.checkCancellation()
            }
            try await saveStep()
        } catch {
            // Add error to thread
            await modifyThreadModelIfRunIdStillMatches { state in
                // Do not modify state if cancelled
                if (error as? CancellationError) == nil {
                    state.status = .stoppedWithError("\(error)")
                }
            }
            throw error
        }
        // Do not modify state if cancelled
        if !Task.isCancelled {
            await modifyThreadModelIfRunIdStillMatches { state in
                // If not in error state, set state to none
                if case .running = state.status {
                    state.status = .none
                }
            }
        }
        return finishResult
    }
    
    // Returns true if we should CONTINUE w/ the loop, false if we should break
    private func handleFunctionCalls(agent: AgentInfo, step: Binding<ThreadModel.Step>) async throws -> Bool {
        // First, see if we can handle this message as a psuedo-function.
        // There are two cases:
        // 1. if there are no other fn calls
        // 2. if there are other fn calls
        var psuedoFnTool: Tool?
        if let msg = step.wrappedValue.assistantMessageForUser {
            let plaintext = msg.asPlainText
            psuedoFnTool = try await agent.tools.concurrentMapThrowing({ try await $0.canHandlePsuedoFunction(fromPlaintext: plaintext) ? $0 : nil }).compactMap(\.self).first
            
            // Convert this assistant message into a tool-use loop
            if psuedoFnTool != nil {
                step.wrappedValue.assistantMessageForUser = nil // Remove final assistant msg, since we handled this as a fn call.
                step.wrappedValue.toolUseLoop.append(.init(initialResponse: msg, computerResponse: []))
            }
            
        } else if let lastToolUseStep = step.wrappedValue.lastToolUseStep {
            try Task.checkCancellation()
            assert(!lastToolUseStep.isComplete)
            let plaintext = lastToolUseStep.initialResponse.asPlainText
            psuedoFnTool = try await agent.tools.concurrentMapThrowing({ try await $0.canHandlePsuedoFunction(fromPlaintext: plaintext) ? $0 : nil }).compactMap(\.self).first
        }
        
        if let finalMsg = step.wrappedValue.assistantMessageForUser {
            print("[\(agent.name)] Received final response (no function calls): \(finalMsg.asPlainText)")
            // expect assistantMessageForUser has been set by appendOrUpdatePartialResponse
            return false // we're done!
        }
        
        try Task.checkCancellation()
        // Let's assume we have an incomplete tool-use step
        assert(step.lastToolUseStep.wrappedValue != nil)
        assert(!step.wrappedValue.lastToolUseStep!.isComplete)
        
        // The last text response is EITHER in the tool-use loop already (if it had normal fn calls) OR in the assistant message response (if no tool use but MAYBE psuedo fn)
        let psuedoFnToolContext = ToolContext(activeDirectory: agent.folder, log: {
            step.wrappedValue.lastToolUseStep?.psuedoFunctionLogs.append($0)
        }, document: agent.document, autorun: agent.autorun)
        
        if let psuedoFnTool {
            let resp = try await handlePsuedoFunction(plaintextResponse: step.wrappedValue.lastToolUseStep!.initialResponse.asPlainText, agentName: agent.name, tool: psuedoFnTool, toolCtx: psuedoFnToolContext)
            step.wrappedValue.lastToolUseStep?.psuedoFunctionResponse = resp
        }
        
        // Now, handle all fn calls:
        for fnCall in step.wrappedValue.lastToolUseStep!.initialResponse.functionCalls {
            let toolCtx = ToolContext(
                activeDirectory: agent.folder,
                log: { step.wrappedValue.lastToolUseStep?.functionCallLogs[fnCall.id ?? "", default: []].append($0) },
                document: agent.document,
                autorun: agent.autorun)
            let resp = try await handleFunctionCall(fnCall, tools: agent.tools, toolCtx: toolCtx)
            step.wrappedValue.lastToolUseStep!.computerResponse.append(resp)
        }
        
        return true // Continue
    }

    private func handlePsuedoFunction(plaintextResponse: String?, agentName: String, tool: Tool, toolCtx: ToolContext) async throws -> [ContextItem]? {
        guard let plaintextResponse else { return nil }
        if let resp = try await tool.handlePsuedoFunction(fromPlaintext: plaintextResponse, context: toolCtx) {
            return resp
        }
        return nil
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
    
    var withIncompleteStepsFixed: ThreadModel {
        var m = self
        m.fixIncompleteSteps()
        return m
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
    var lastToolUseStep: ToolUseStep? {
        get {
            toolUseLoop.count > 0 ? toolUseLoop[toolUseLoop.count - 1] : nil
        }
        set {
            if let newValue, toolUseLoop.count > 0 {
                toolUseLoop[toolUseLoop.count - 1] = newValue
            }
        }
    }
    
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
            if let lastToolUseStep = toolUseLoop.last, lastToolUseStep.computerResponse.isEmpty && lastToolUseStep.psuedoFunctionResponse == nil {
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
            psuedoFunctionResponse = [.text("[Response was interrupted]")]
//            psuedoFunctionResponse = .init(role: .user, content: [.text("[Response was interrupted]")])
        }
    }
}
