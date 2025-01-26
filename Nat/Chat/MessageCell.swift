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
//            Text("\(string)")
//                .font(.caption)
//                .foregroundStyle(.secondary)
//                .lineLimit(nil)
//                .multilineTextAlignment(.center)
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
        }
    }
}
