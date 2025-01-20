import ChatToys
import SwiftUI

struct DebugThreadView: View {
    @Environment(\.document) private var document
    @State private var threadModel: ThreadModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let threadModel {
                    ForEach(threadModel.steps) {
                        StepView(step: $0)
                    }
                    Text("status: \(threadModel.isTyping ? "typing" : "finished")")
                }
            }
            .padding()
        }
        .onReceive(document.store.publisher.map(\.thread).throttle(for: .seconds(2), scheduler: DispatchQueue.main, latest: true), perform: { self.threadModel = $0 })
    }
}

private struct StepView: View {
    var step: ThreadModel.Step

    var body: some View {
        Group {
            Text("User message:")
                .font(.caption)

            MessageBubble(isFromUser: true) {
                Text(step.initialRequest.asLLMMessage().contentDescription)
                    .padding(6)
            }

            ForEachUnidentifiable(items: Array(step.toolUseLoop.enumerated())) { pair in
                let (i, loopStep) = pair
                Text("Assistant used tool (step #\(i))")
                    .font(.caption)

                VStack(alignment: .leading) {
                    Text(loopStep.initialResponse.asPlainText)
                    ForEachUnidentifiable(items: loopStep.initialResponse.functionCalls) { call in
                        Text("\(call.name)(\(call.arguments))").font(Font.body.monospaced())
                            .foregroundStyle(Color.purple)

                        if let resp = loopStep.computerResponse.first(where: { $0.id == call.id }) {
                            Text(resp.text)
                                .italic()
                                .foregroundStyle(Color.blue)
                        } else {
                            Text("[No response attached]").italic()
                        }
                    }
                    if let pfr = loopStep.psuedoFunctionResponse {
                        Text("Message above was parsed as a psuedo-function. Response:")
                            .italic()
                            .foregroundStyle(.red)
                        Text(pfr.content)
                            .italic()
                            .foregroundStyle(Color.blue)
                    }
                }
                .padding(.leading)
                .overlay(alignment: .leading) {
                    Color.primary.frame(width: 2)
                }
            }

            if let final = step.assistantMessageForUser {
                Text("Final assistant msg:")
                    .font(.caption)

                Text(final.content)
            }
        }
        .multilineTextAlignment(.leading)
        .lineLimit(nil)
        Divider()
    }
}
