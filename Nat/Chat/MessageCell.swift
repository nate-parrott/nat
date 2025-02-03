
import SwiftUI
import ChatToys

struct MessageCell: View {
    var model: MessageCellModel
    
    var body: some View {
        switch model.content {
        case .userMessage(let string):
            Text(string)
                .textSelection(.enabled)
                .foregroundStyle(.white)
                .modifier(CellBackdropModifier(enabled: true, tint: Color.blue))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading)
        case .assistantMessage(let string):
            AssistantMessageView(text: string)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .toolLog(let log):
            LogView(msgId: model.id, log: log)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .codeEdit(let edit):
            CodeEditInlineView(edit: edit, msgId: model.id) // has cell BG already
                .frame(maxWidth: .infinity, alignment: .leading)
        case .error(let string):
            Text("\(string)")
                .font(.caption)
                .bold()
                .foregroundStyle(.red)
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}


private struct CodeEditInlineView: View {
    var edit: CodeEdit
    var msgId: String
        
    var body: some View {
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
        .frame(maxWidth: 300, alignment: .leading)
        .modifier(CellBackdropModifier(enabled: true))
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
        
    var body: some View {
        switch log {
        case .readFile(let path):
            Label("Read file: `\(path.lastPathComponent)`", systemImage: "doc")
        case .usingEditCleanupModel(let url):
            Label("Using edit cleanup model for `\(url.lastPathComponent)`", systemImage: "bandage")
        case .grepped(let query):
            Label("Searched for: `\(query)`", systemImage: "magnifyingglass")
        case .edits(let edits):
            let paths = edits.paths.map(\.lastPathComponent).uniqued.joined(separator: ", ")
            if edits.accepted {
                if let comment = edits.comment {
                    Label("Accepted edits to `\(paths)` with comment: **'\(comment)'**", systemImage: "checkmark")
                } else {
                    Label("Accepted edits to `\(paths)`", systemImage: "checkmark")
                }
            } else {
                if let comment = edits.comment {
                    Label("Rejected edits to `\(paths)` with comment: **'\(comment)'**", systemImage: "xmark")
                } else {
                    Label("Rejected edits to `\(paths)`", systemImage: "xmark")
                }
            }
        case .deletedFile(let path):
            Label("Deleted file: `\(path)`", systemImage: "trash")
        case .codeSearch(let query):
            Label("Searched code for: `\(query)`", systemImage: "magnifyingglass")
        case .listedFiles:
            Label("Listed files", systemImage: "folder")
        case .toolError(let error):
            Label("Error: \(error)", systemImage: "exclamationmark.triangle")
        case .toolWarning(let warning):
            Label("Warning: \(warning)", systemImage: "exclamationmark.triangle.fill")
        case .webSearch(let query):
            Label("Searched web for: `\(query)`", systemImage: "globe")
        case .tokenUsage(let prompt, let completion, let model):
            Label("Used \(prompt + completion) tokens (\(model))", systemImage: "dollarsign.circle")
        case .effort(let description):
            Label("Effort: \(description)", systemImage: "person.fill")
        case .terminal(let command):
            Label("Ran command: `\(command)`", systemImage: "terminal")
        }
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
                    Text(text.prefix(1200) + "...")
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
