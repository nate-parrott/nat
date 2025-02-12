import SwiftUI

struct DictationModifier: ViewModifier {
    let priority: Int
    @Binding var state: DictationClient.State
    let onDictatedText: (String) -> Void
    @StateObject private var dictationClient = DictationClient()
    @Environment(\.controlActiveState) private var controlActiveState
    
    func body(content: Content) -> some View {
        content
            .onChange(of: controlActiveState) { newValue in
                dictationClient.priority = newValue == .key ? priority : nil
            }
            .onAppear {
                dictationClient.registered = true
                dictationClient.priority = controlActiveState == .key ? priority : nil
                dictationClient.onDictatedText = onDictatedText
            }
            .onDisappear {
                dictationClient.registered = false
            }
            .onChange(of: dictationClient.state) { newValue in
                state = newValue
            }
    }
}

extension View {
    func dictationUI(state: DictationClient.State) -> some View {
        self.opacity(state == .none ? 1 : 0.05)
            .background {
                if state != .none {
                    Color.blue.opacity(0.05)
                    Color.blue.opacity(0.1)
                        .modifier(PulseAnimationModifier())
                }
            }
            .overlay(alignment: .leading) {
                Group {
                    switch state {
                    case .none: EmptyView()
                    case .startingToRecord, .recording:
                        VStack(alignment: .leading, spacing: 4) {
                            let previewText = state.previewText
                            HStack {
                                if let text = previewText?.nilIfEmpty {
                                    Waveform(text: text)
                                } else {
                                    Text(previewText?.nilIfEmpty ?? "Listening...")
                                        .bold()
                                }
                                Spacer()
                                    .foregroundStyle(.secondary)
                                Text(markdown: "Press _Caps Lock_ again to stop")
                                    .lineLimit(1)
                            }
                        }
                        .transition(.upDown())
                    case .recognizingSpeech:
                        Text("Transcribing...")
                            .bold()
//                            .modifier(PulseAnimationModifier())
                            .transition(.upDown())
                    }
                }
                .foregroundStyle(Color.blue)
                .padding(.horizontal)
            }
            .animation(.niceDefault, value: state)
    }
}

extension AnyTransition {
    static func upDown(dist: CGFloat = 10) -> AnyTransition {
        self.opacity.combined(with: .asymmetric(insertion: .offset(y: dist), removal: .offset(y: -dist)))
    }
}

struct PulseAnimationModifier: ViewModifier {
    var duration: TimeInterval = 1
    var active = true
    
    @State private var onState = false
    
    func body(content: Content) -> some View {
        content
        // Written by Phil
//        .scaleEffect(onState ? 1.1 : 1.0)
        .opacity(onState ? 0.5 : 1.0)
        .onAppearOrChange(of: active) {
            if $0 {
                withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    onState = true
                }
            } else {
                onState = false
            }
        }
    }
}

extension DictationClient.State {
    var previewText: String? {
        if case .recording(let previewText) = self {
            return previewText
        }
        return nil
    }
}

private struct Waveform: View {
    var text: String
    
    var body: some View {
        Text(text.truncateTailWithEllipsis(chars: 200))
            .animation(.niceDefault, value: text)
            .blur(radius: 5)
        
//        PerFrameAnimationView(t: min(50, CGFloat(text.count * 2))) { count in
//            let array: [Int] = Array(0...Int(count))
//            ForEachUnidentifiable(items: array) { i in
//                let height = remap(x: sin(CGFloat(i) / 10), domainStart: -1, domainEnd: 1, rangeStart: 6, rangeEnd: 18)
//                HStack(spacing: 3) {
//                    Color.primary.frame(width: 1.5, height: height)
//                        .opacity(0.7)
//                        .transition(.scale.animation(.spring(response: 0.1, dampingFraction: 0.5, blendDuration: 0.1)))
//                }
//            }
//        }
//        .animation(.niceDefault(duration: 0.5), value: text.count)
    }
}
