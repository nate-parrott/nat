import SwiftUI
import ChatToys

struct MessageCell: View {
    var model: MessageCellModel

    var body: some View {
        switch model.content {
        case .userMessage(let string):
            TextMessageBubble(Text(string), isFromUser: true)
        case .assistantMessage(let string):
            TextMessageBubble(Text(string), isFromUser: false)
        case .toolUse(let string):
            Text("\(string)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .multilineTextAlignment(.center)
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
