import SwiftUI
import ChatToys

struct MessageCell: View {
    var model: MessageCellModel

    var body: some View {
        switch model.content {
        case .userMessage(let string):
            TextMessageBubble(Text(string), isFromUser: true)
        case .assistantMessage(let string):
            Text(string)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
//            TextMessageBubble(Text(string), isFromUser: false)
        case .toolLog(let log):
            switch log {
            case .readFile(let string):
                LogView(markdown: "Read **\(string)**", symbol: "eyeglasses")
            case .editedFile(let string):
                LogView(markdown: "Edited **\(string)**", symbol: "pencil")
            case .rejectedEdit(let string):
                LogView(markdown: "Rejected edit of **\(string)**", symbol: "xmark")
            case .requestedChanges(let string):
                LogView(markdown: "Requested change to edit of **\(string)**", symbol: "shuffle")
            case .createdFile(let string):
                LogView(markdown: "Created **\(string)**", symbol: "plus")
            case .codeSearch(let string):
                LogView(markdown: "Code search for _\(string)_", symbol: "magnifyingglass")
            case .listedFiles:
                LogView(markdown: "Listed files", symbol: "list.bullet")
            case .toolError(let error):
                LogView(markdown: error, symbol: "exclamationmark.triangle.fill")
            }
//        case .toolUse(let string):
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
