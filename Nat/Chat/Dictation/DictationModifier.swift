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
                dictationClient.priority = controlActiveState == .key ? priority : nil
                dictationClient.onDictatedText = onDictatedText
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
                    case .none, .startingToRecord: EmptyView()
                    case .recording:
                        HStack {
                            Text("Listening...")
                                .bold()
                            Text(markdown: "Press _Caps Lock_ again to stop")
                        }
//                            .modifier(PulseAnimationModifier())
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
