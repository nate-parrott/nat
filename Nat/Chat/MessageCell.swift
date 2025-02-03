import SwiftUI
import ChatToys

struct MessageCell: View {
    var model: MessageCellModel
    var backdrop = false
    var showCodeEditCards = true
    @State private var isFocused = false
    
    var body: some View {
        switch model.content {
        case .userMessage(let string):
            Text(string)
                .textSelection(.enabled)
                .foregroundStyle(.white)
                .modifier(CellBackdropModifier(enabled: true, tint: Color.blue))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading)
//            TextMessageBubble(Text(string), isFromUser: true)
        case .assistantMessage(let string):
            AssistantMessageView(text: string)
                .modifier(CellBackdropModifier(enabled: backdrop))
                .frame(maxWidth: .infinity, alignment: .leading)
//            TextMessageBubble(Text(string), isFromUser: false)
        case .toolLog(let log):
            Group {
                LogView(msgId: model.id, log: log, forceBackdrop: backdrop)
            }
            .modifier(CellBackdropModifier(enabled: backdrop))
            .frame(maxWidth: .infinity, alignment: .leading)
        case .codeEdit(let edit):
            if showCodeEditCards {
                CodeEditInlineView(edit: edit, msgId: model.id) // has cell BG already
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Label("Proposed code edit", systemImage: "keyboard")
//                Label(markdown: "Proposed code edit", symbol: "keyboard")
                    .modifier(CellBackdropModifier(enabled: backdrop))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .error(let string):
            Text("\(string)")
                .font(.caption)
                .bold()
                .foregroundStyle(.red)
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .modifier(CellBackdropModifier(enabled: backdrop))
                .frame(maxWidth: .infinity)
        }
    }
}


private struct CodeEditInlineView: View {
    var edit: CodeEdit
    var msgId: String
    
    @State private var focused = false

    var body: some View {
        let outline = RoundedRectangle(cornerRadius: 8, style: .continuous)
        VStack(alignment: .leading, spacing: 4) {
            switch edit {
            case .replace(let path, _, _, let lines):
                Text("Edit " + path.lastPathComponent).bold()
                body(lines: lines)
            case .write(let path, let content):
                Text("Write to " + path.lastPathComponent).bold()
                body(lines: content.lines)
            case .append(let path, let content):
                Text("Append to " + path.lastPathComponent).bold()
                body(lines: content.lines)
            case .findReplace(let path, _, let replace):
                Text("Edit " + path.lastPathComponent).bold()
                body(lines: replace)
            }
        }
        .font(Font.system(size: 12, weight: .bold))
//        .foregroundStyle(.primary)
        .frame(maxWidth: 300, alignment: .leading)
        .clipShape(outline)
        .modifier(CellBackdropModifier(enabled: true))
        .modifier(FocusableCell(id: msgId, focused: $focused))
    }

    @ViewBuilder func body(lines: [String]) -> some View {
        Text(lines.suffix(5).joined(separator: "\n"))
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .opacity(0.7)
            .lineLimit(5)
            .fixedSize(horizontal: true, vertical: true)
    }
}

private struct LogView: View {
    var msgId: String
    var log: UserVisibleLog
    var forceBackdrop: Bool
    
    @State private var focused = false

    var body: some View {
        let (markdown, symbol) = log.asMarkdownAndSymbol
        
        if log.hasFocusDetail {
            Label(LocalizedStringKey(markdown), systemImage: symbol)
                .modifier(FocusableCell(id: msgId, focused: $focused))
                .modifier(CellBackdropModifier(enabled: true, tint: Color.purple))

        } else {
            Label(LocalizedStringKey(markdown), systemImage: symbol)
                .modifier(CellBackdropModifier(enabled: forceBackdrop))
        }
//            .foregroundStyle(.purple)
//            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AssistantMessageView: View {
    var text: String
    @State private var expanded = false

    var body: some View {
        Group {
            if text.count > 1200 {
                if expanded {
                    Text(text)
                    Text("Collapse").foregroundStyle(.blue).onTapGesture {
                        expanded = false
                    }
                } else {
                    Text(text.prefix(1200) + "…")
                    Label("Show all", systemImage: "scissors")
                        .foregroundStyle(.blue)
                        .onTapGesture {  expanded = true }
                }
            } else {
                Text(text)
            }
        }
        .textSelection(.enabled)
        .multilineTextAlignment(.leading)
    }
}

extension UserVisibleLog {
    var asMarkdownAndSymbol: (String, String) {
        switch self {
        case .readFile(let path):
            return ("Read file: `\(path.lastPathComponent)`", "doc")
        case .usingEditCleanupModel(let url):
            return ("Using edit cleanup model for `\(url.lastPathComponent)`", "bandage")
        case .grepped(let query):
            return ("Searched for: `\(query)`", "magnifyingglass")
        case .edits(let edits):
            let paths = edits.paths.map(\.lastPathComponent).joined(separator: ", ")
            if edits.accepted {
                if let comment = edits.comment {
                    return ("Accepted edits to `\(paths)` with comment: **'\(comment)'**", "checkmark")
                } else {
                    return ("Accepted edits to `\(paths)`", "checkmark")
                }
            } else {
                if let comment = edits.comment {
                    return ("Rejected edits to `\(paths)` with comment: **'\(comment)'**", "xmark")
                } else {
                    return ("Rejected edits to `\(paths)`", "xmark")
                }

            }
        case .deletedFile(let path):
            return ("Deleted file: `\(path)`", "trash")
        case .codeSearch(let query):
            return ("Searched code for: `\(query)`", "magnifyingglass")
        case .listedFiles:
            return ("Listed files", "folder")
        case .toolError(let error):
            return ("Error: \(error)", "exclamationmark.triangle")
        case .terminal(let command):
            return ("Running: `\(command)`", "terminal")
        case .tokenUsage(let prompt, let completion, let model):
            return ("Token usage: \(prompt) prompt + \(completion) completion (\(model))", "dollarsign.circle")
        case .effort(let effort):
            return (effort, "flame")
        case .webSearch(let query):
            return ("Web research: _\(query)_", "globe")
        case .toolWarning(let text):
            return (text, "exclamationmark.triangle.fill")
        }
    }
}
