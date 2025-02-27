import Foundation

// Terminal client that reads
@MainActor
class NewTerminalClient: ObservableObject {
    @Published var outbox = "" // All text emitted since it was last collected, from stdout and stderr
    @Published var readyYet = false
    
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var outputTasks: [Task<Void, any Error>] = []
    private var allOutput = "" // Private copy of all output for prompt detection
    @Published private var lastPromptSeen: Date?
    
    init() {
        Task {
            await setupProcess()
        }
    }
    
    private func setupProcess() async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l"] // Login shell
        
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        // Store for later use
        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        
        // Set up output handling
        let stdoutTask = Task {
            for try await data in stdoutPipe.fileHandleForReading.bytes {
                if let str = String(data: Data([data]), encoding: .utf8) {
                    self.outbox += str
                    self.allOutput += str
                    
                    // Check for prompts
                    if ["% ", ">>> ", "... "].contains(where: { self.allOutput.hasSuffix($0) }) {
                        self.lastPromptSeen = .now
                    }
                }
            }
        }
        
        let stderrTask = Task {
            for try await data in stderrPipe.fileHandleForReading.bytes {
                if let str = String(data: Data([data]), encoding: .utf8) {
                    self.outbox += str
                    self.allOutput += str
                }
            }
        }
        
        outputTasks = [stdoutTask, stderrTask]
        
        do {
            try process.run()
            
            // Configure prompt
            try await send(command: "PS1='$ %~ % '\n", maxWaitDuration: 1.0)
            readyYet = true
            
        } catch {
            print("Failed to start shell: \(error)")
        }
    }
    
    // Sends text to shell stdin (must include newline if sending a command).
    // If `maxWaitDuration` > 0, waits until EITHER a maxWaitDuration elapses OR we encounter a 'waiting heuristic' like the current shell prompt OR the python3 repl prompt ('>>> ') or something similar
    func send(command: String, maxWaitDuration: TimeInterval) async throws {
        guard let stdinPipe = stdinPipe else { return }
        
        let commandStart = Date()
        try stdinPipe.fileHandleForWriting.write(contentsOf: command.data(using: .utf8)!)
        
        if maxWaitDuration > 0 {
            let start = Date()
            while Date().timeIntervalSince(start) < maxWaitDuration {
                if let promptTime = lastPromptSeen,
                   promptTime >= commandStart {
                    return
                }
                try await Task.sleep(seconds: 0.1)
            }
        }
    }
    
    // Sends text to shell stdin (must include newline if sending a command).
    // If `maxWaitDuration` > 0, waits until EITHER a maxWaitDuration elapses OR we encounter a 'waiting heuristic' like the current shell prompt OR the python3 repl prompt ('>>> ') or something similar
    // Streams output until the wait condition occurs
    func sendAndCaptureOutput(command: String, maxWaitDuration: TimeInterval) -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                let startOutbox = outbox
                guard let stdinPipe = stdinPipe else {
                    continuation.finish()
                    return
                }
                
                do {
                    let commandStart = Date()
                    try stdinPipe.fileHandleForWriting.write(contentsOf: command.data(using: .utf8)!)
                    
                    if maxWaitDuration > 0 {
                        var lastLen = startOutbox.count
                        
                        while Date().timeIntervalSince(commandStart) < maxWaitDuration {
                            let newLen = outbox.count
                            if newLen > lastLen {
                                let newOutput = String(outbox.dropFirst(lastLen))
                                continuation.yield(newOutput)
                                lastLen = newLen
                            }
                            
                            if let promptTime = lastPromptSeen,
                               promptTime >= commandStart {
                                break
                            }
                            
                            try await Task.sleep(seconds: 0.1)
                        }
                    }
                } catch {
                    print("Error in sendAndCaptureOutput: \(error)")
                }
                
                continuation.finish()
            }
        }
    }
    
    func sendInterrupt() {
        Task {
            do {
                try await send(command: "\u{4}", maxWaitDuration: 0) // ^D (EOF)
            } catch {
                print("Failed to send interrupt: \(error)")
            }
        }
    }
    
    private func awaitReady() async {
        for await ready in $readyYet.values {
            if ready { return }
        }
    }
    
    deinit {
        outputTasks.forEach { $0.cancel() }
        process?.terminate()
    }
}
