import SwiftUI
import ChatToys

struct MessageCell: View {
    var model: MessageCellModel

    var body: some View {
        switch model.content {
        case .userMessage(let string):
            TextMessageBubble(Text(string), isFromUser: true)
        case .assistantMessage(let string):
            AssistantMessageView(text: string)
//            TextMessageBubble(Text(string), isFromUser: false)
        case .toolLog(let log):
            let (markdown, symbol) = log.asMarkdownAndSymbol
            if case .terminal = log {
                Label(markdown, systemImage: symbol)
                    .font(Font.body.monospaced())
                    .foregroundStyle(.purple)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LogView(markdown: markdown, symbol: symbol)
            }
        case .codeEdit(let edit):
            CodeEditInlineView(edit: edit)
        case .error(let string):
            Text("\(string)")
                .font(.caption)
                .bold()
                .foregroundStyle(.red)
                .lineLimit(nil)
                .multilineTextAlignment(.center)
        }
    }
}

private struct CodeEditInlineView: View {
    var edit: CodeEdit

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
        .foregroundStyle(.white)
        .frame(maxWidth: 300, alignment: .leading)
        .padding(6)
//        .frame(maxHeight: 100)
//        .overlay(alignment: .top) {
//            LinearGradient(colors: [Color.black.opacity(0), Color.black], startPoint: .init(x: 0, y: 0.9), endPoint: .init(x: 0, y: 1))
//                .frame(height: 100)
//        }
//        .background(Color.black)
//        .clipShape(outline)
        .background(outline.fill(Color.white).shadow(radius: 4).opacity(0.15))
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
    var markdown: String
    var symbol: String

    var body: some View {
        Label(LocalizedStringKey(markdown), systemImage: symbol)
            .foregroundStyle(.purple)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension UserVisibleLog {
    var asMarkdownAndSymbol: (String, String) {
        switch self {
        case .readFile(let path):
            return ("Read file: `\(path)`", "doc")
        case .grepped(let query):
            return ("Searched for: `\(query)`", "magnifyingglass")
        case .editedFile(let path):
            return ("Edited file: `\(path)`", "pencil")
        case .rejectedEdit(let path):
            return ("Rejected edit to: `\(path)`", "xmark")
        case .requestedChanges(let path):
            return ("Requested changes to: `\(path)`", "exclamationmark.triangle")
        case .wroteFile(let path):
            return ("Wrote file: `\(path)`", "plus.circle")
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
        case .info(let text):
            return (text, "info")
        case .toolWarning(let text):
            return (text, "exclamationmark.triangle.fill")
        }
    }
}
