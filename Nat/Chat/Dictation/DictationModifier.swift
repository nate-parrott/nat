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
    func dictation(
        priority: Int,
        state: Binding<DictationClient.State>,
        onText: @escaping (String) -> Void
    ) -> some View {
        modifier(DictationModifier(
            priority: priority,
            state: state,
            onDictatedText: onText
        ))
    }
}