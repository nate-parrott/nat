# Data Types and Models

## Core Data Models

### Document & State
- `Document.swift`: Main document model that ties everything together
- `DocumentState`: Core state model with thread, folder paths, mode, settings
  - Stored in `DocumentStore<Model>` for persistence
  - Key fields: thread (ThreadModel), folder (URL), mode (DocumentMode)

### Threading Model 
- `ThreadModel.swift`: Core conversation/agent interaction model
- Key types:
  - `ThreadModel.Step`: One complete interaction cycle
  - `Step.ToolUseStep`: Tool usage within a step
  - `UserVisibleLog`: Events shown in UI (file reads, edits, searches etc)

### Messages
- `TaggedLLMMessage`: Enhanced LLM messages with metadata
  - Contains: role, content items, function calls/responses
- `ContextItem`: Individual message content types
  - Cases: text, fileSnippet, image, systemInstruction etc
  - Used for attachments and message content

## UI Models

### Document Modes
- `DocumentMode`: Main UI modes (.agent, .codeSearch, .docs)
- Controls which view is shown (ChatView, CodeSearchView, DocsView)

### Views
- `ChatInput`: Main chat interface
  - Handles text input, attachments, status
- `DocsView`: Documentation browser/editor
  - Manages nat_docs folder content

## Data Flow

### Document Flow
1. Document loads/creates DocumentState
2. State managed by DataStore<Model> for persistence
3. Changes propagate via Combine publishers
4. UI subscribes via .onReceive() 

### Agent Interaction Flow
1. User input -> ThreadModel.Step created
2. Step contains:
   - Initial request
   - Tool use loop (functions/responses)
   - Final assistant message
3. Tools record logs via UserVisibleLog
4. UI updates based on ThreadModel changes

### File Operations
- FileSnippet: Code snippet with metadata
- Paths tracked relative to document folder
- File edits logged and managed through ThreadModel

## Key Files
- /Nat/Document.swift: Core document model
- /Nat/Agent/ThreadModel.swift: Conversation model
- /Nat/Agent/ContextItem.swift: Message content types
- /Nat/Utils/DataStore.swift: Persistence layer
- /Nat/Chat/ChatInput.swift: Main UI entry point
- /Nat/Views/Docs/DocsView.swift: Documentation UI

## Edge Cases
- Incomplete ThreadModel.Steps (failed actions)
- Message truncation in long threads 
- Tool function responses vs pseudo-functions
- File path resolution (project-relative vs absolute)