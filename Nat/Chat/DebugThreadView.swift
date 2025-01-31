import ChatToys
import SwiftUI

struct DebugThreadView: View {
    @Environment(\.document) private var document
    @State private var threadModel: ThreadModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let threadModel {
                    let msgs = threadModel
                        .steps
                        .flatMap(\.asTaggedLLMMessages)
                        .truncateTaggedLLMessages()
                        .byDroppingRedundantContext()
                        .asArray
                    ForEachUnidentifiable(items: msgs) { msg in
                        MsgDebugView(msg: msg)
                    }
//                    ForEach(threadModel.steps) {
//                        StepView(step: $0)
//                    }
                    Text("status: \(threadModel.status)")
                }
            }
            .padding()
        }
        .onReceive(document.store.publisher.map(\.thread).throttle(for: .seconds(2), scheduler: DispatchQueue.main, latest: true), perform: { self.threadModel = $0 })
    }
}

private struct MsgDebugView: View {
    var msg: TaggedLLMMessage

    var body: some View {
        Group {
            if msg.role == .user {
                MessageBubble(isFromUser: true) {
                    Text(msg.asLLMMessage().contentDescription)
                        .padding(6)
                }
            } else {
                Text("\(msg.role)").font(.caption).foregroundStyle(.blue)

                ContextItemView(items: msg.content)
                    .id("Items")

                ForEachUnidentifiable(items: msg.functionCalls) { call in
                    Text("\(call.name)(\(call.arguments))")
                        .monospaced()
                }
                .id("Calls")

                VStack {
                    ForEachUnidentifiable(items: msg.functionResponses) { resp in
                        Text("Function response to \(resp.functionName)")
                        ContextItemView(items: resp.content)
                    }
                }
                .padding(.leading)
                .id("Responses")
            }
        }
    }
}

//private struct StepView: View {
//    var step: ThreadModel.Step
//
//    var body: some View {
//        Group {
//            Text("User message:")
//                .font(.caption)
//
//            MessageBubble(isFromUser: true) {
//                Text(step.initialRequest.asLLMMessage().contentDescription)
//                    .padding(6)
//            }
//
//            ForEachUnidentifiable(items: Array(step.toolUseLoop.enumerated())) { pair in
//                let (i, loopStep) = pair
//                Text("Assistant used tool (step #\(i))")
//                    .font(.caption)
//
//                VStack(alignment: .leading) {
////                    Text(loopStep.initialResponse.asPlainText)
//                    ContextItemView(items: loopStep.initialResponse.content)
//
//                    ForEachUnidentifiable(items: loopStep.initialResponse.functionCalls) { call in
//                        Text("\(call.name)(\(call.arguments))").font(Font.body.monospaced())
//                            .foregroundStyle(Color.purple)
//
//                        if let resp = loopStep.computerResponse.first(where: { $0.functionId == call.id }) {
//                            ContextItemView(items: resp.content)
//                                .italic()
//                                .foregroundStyle(Color.blue)
//                        } else {
//                            Text("[No response attached]").italic()
//                        }
//                    }
//                    if let pfr = loopStep.psuedoFunctionResponse {
//                        Text("Message above was parsed as a psuedo-function. Response:")
//                            .italic()
//                            .foregroundStyle(.red)
//
//                        ContextItemView(items: pfr.content)
//                            .italic()
//                            .foregroundStyle(Color.blue)
//                    }
//                }
//                .padding(.leading)
//                .overlay(alignment: .leading) {
//                    Color.primary.frame(width: 2)
//                }
//            }
//
//            if let final = step.assistantMessageForUser {
//                Text("Final assistant msg:")
//                    .font(.caption)
//
//                ContextItemView(items: final.content)
//            }
//        }
//        .multilineTextAlignment(.leading)
//        .lineLimit(nil)
//        Divider()
//    }
//}

private struct ContextItemView: View {
    var items: [ContextItem]

    var body: some View {
        ForEachUnidentifiable(items: items) { item in
            switch item {
            case .fileSnippet(let snippet):
                Text(snippet.asString(withLineNumbers: Constants.useLineNumbers))
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 5).opacity(0.2))
            case .text(let text):
                Text(text)
            case .image:
                Text("[Image]")
            case .systemInstruction(let sys):
                Text("<system>\(sys)</system>")
            case .textFile(filename: let filename, content: let content):
                Text("File:\n\(content)")
            case .url(let url):
                Text("URL:\n\(url.absoluteString)")
            case .largePaste(let text):
                Text("Large paste:\n\(text)")
            case .omission(let msg):
                Text("Omission: \(msg)")
                    .foregroundStyle(.red)
            }
        }
    }
}
