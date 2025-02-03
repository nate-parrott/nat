import SwiftUI
import ChatToys

struct MessageCell: View {
    var model: MessageCellModel
    var backdrop = false
    var showCodeEditCards = true

    var body: some View {
        switch model.content {
        case .userMessage(let string):
            Text(string)
                .foregroundStyle(.white)
                .withCellBackdrop(true, blue: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
//            TextMessageBubble(Text(string), isFromUser: true)
        case .assistantMessage(let string):
            AssistantMessageView(text: string)
                .withCellBackdrop(backdrop)
                .frame(maxWidth: .infinity, alignment: .leading)
//            TextMessageBubble(Text(string), isFromUser: false)
        case .toolLog(let log):
            Group {
                let (markdown, symbol) = log.asMarkdownAndSymbol
                if case .terminal = log {
                    Label(markdown, systemImage: symbol)
                        .font(Font.body.monospaced())
                        .foregroundStyle(.purple)
                } else {
                    LogView(markdown: markdown, symbol: symbol)
                }
            }
            .withCellBackdrop(backdrop)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .codeEdit(let edit):
            if showCodeEditCards {
                CodeEditInlineView(edit: edit) // has cell BG already
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LogView(markdown: "Proposed code edit", symbol: "keyboard")
                    .withCellBackdrop(backdrop)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .error(let string):
            Text("\(string)")
                .font(.caption)
                .bold()
                .foregroundStyle(.red)
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .withCellBackdrop(backdrop)
                .frame(maxWidth: .infinity)
        }
    }
}

private extension View {
    @ViewBuilder
    func withCellBackdrop(_ backdrop: Bool = true, blue: Bool = false) -> some View {
        if backdrop {
            self
                .padding(.horizontal, backdrop ? 8 : 0)
                .padding(.vertical, backdrop ? 6 : 0)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1))
                }
                .background {
                    if backdrop {
                        if blue {
                            Color.accentColor
                                .overlay {
                                    LinearGradient(colors: [Color.white, Color.white.opacity(0)], startPoint: .top, endPoint: .bottom)
                                        .opacity(0.1)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .shadow(color: Color.blue.opacity(0.1), radius: 4, x: 0, y: 1)
                        } else {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.thickMaterial)
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                        }
                    }
                }
        } else {
            self
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
//        .foregroundStyle(.primary)
        .frame(maxWidth: 300, alignment: .leading)
//        .padding(6)
//        .frame(maxHeight: 100)
//        .overlay(alignment: .top) {
//            LinearGradient(colors: [Color.black.opacity(0), Color.black], startPoint: .init(x: 0, y: 0.9), endPoint: .init(x: 0, y: 1))
//                .frame(height: 100)
//        }
//        .background(Color.black)
        .clipShape(outline)
        .withCellBackdrop()
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
