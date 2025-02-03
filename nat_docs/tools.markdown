# Tools Implementation Guide

## Overview

Tools in Nat are modular components that provide functionality to the LLM agent. They can be either standard function-based tools or pseudo-functions that parse plain text responses.

## Tool Protocol

Tools implement the `Tool` protocol:

```swift
protocol Tool {
    var functions: [LLMFunction] { get }
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse?
    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String?
    func inlineContextUpdates(previous: String, context: ToolContext) async throws -> String?
    func canHandlePsuedoFunction(fromPlaintext response: String) async throws -> Bool
    func handlePsuedoFunction(fromPlaintext response: String, context: ToolContext) async throws -> [ContextItem]?
}
```

## Types of Tools

1. **Standard Function Tools**
   - Implement `functions` to return LLMFunction definitions
   - Handle function calls via `handleCallIfApplicable`
   - Example: CodeSearchTool, WebResearchTool

2. **Pseudo-Function Tools**
   - Parse plain text responses without formal function call syntax
   - Implement `canHandlePsuedoFunction` and `handlePsuedoFunction`
   - Example: FileEditorTool (handles code fence edits)

## Tool Context

Tools receive a `ToolContext` containing:
- Active directory URL
- Logging function
- Document reference
- Autorun flag

## Registering Tools

Tools are registered in ChatView.swift when sending messages:

```swift
let tools: [Tool] = [
    FileReaderTool(), 
    FileEditorTool(), 
    CodeSearchTool(), 
    FileTreeTool(),
    TerminalTool(), 
    WebResearchTool(), 
    DeleteFileTool(), 
    GrepTool(),
    BasicContextTool(document: document, currentFilenameFromXcode: curFile)
]
```

## Creating a New Tool

1. Create a new struct implementing `Tool`
2. Define functions array if using standard function calls
3. Implement pseudo-function handlers if needed
4. Add tool to the tools array in ChatView.swift

## Tool Patterns

- Tools can provide both function calls and pseudo-functions
- Use pseudo-functions when the response format is more natural in plain text
- Tools can add context at thread start or inline
- Tools should handle their own error cases gracefully