import SwiftUI

struct TerminalTestView: View {
    @StateObject private var terminal = NewTerminalClient()
    @State private var inputText = ""
    @State private var preOutput = ""
    @State private var postOutput = ""
    @State private var isWaiting = false
    @State private var executedAt: Date?
    
    var body: some View {
        HSplitView {
            // Main controls
            VStack(alignment: .leading, spacing: 12) {
            TextField("Command to send", text: $inputText)
                .textFieldStyle(.roundedBorder)
            
            Button("Send (5s timeout)") {
                Task {
                    // Capture pre-state
                    preOutput = terminal.outbox
                    isWaiting = true
                    executedAt = Date()
                    
                    // Send command
                    try? await terminal.send(command: inputText + "\n", maxWaitDuration: 5.0)
                    
                    // Capture post-state
                    postOutput = terminal.outbox
                    terminal.outbox = "" // Clear for next command
                    isWaiting = false
                }
            }
            .disabled(isWaiting)
            
            Group {
                Text("Pre-send outbox:")
                    .bold()
                Text(preOutput)
                    .font(.system(.body, design: .monospaced))

                if let executedAt {
                    Text("Executed at: \(executedAt.formatted())")
                    if isWaiting {
                        Text("Still waiting...")
                            .foregroundStyle(.orange)
                    }
                }
                
                Text("Post-send outbox:")
                    .bold()
                Text(postOutput)
                    .font(.system(.body, design: .monospaced))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(width: 500)
            
            // Sidebar with running log
            ScrollView {
                Text(terminal.outbox)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(width: 300)
            .background(Color(.textBackgroundColor))
        }
    }
}

#Preview {
    TerminalTestView()
}