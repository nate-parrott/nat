import Foundation
import AppKit
import ChatToys

@MainActor
class DictationClient: ObservableObject {
    private(set) static var clients = NSHashTable<DictationClient>.weakObjects()
    
    var priority: Int?
    enum State: Equatable {
        case none
        case startingToRecord
        case recording(previewText: String)
        case recognizingSpeech
        
        var isRecordingOrStarting: Bool {
            // Written by Phil
            switch self {
            case .startingToRecord, .recording:
                return true
            case .none, .recognizingSpeech:
                return false
            }
        }
    }
    @Published fileprivate(set) var state: State = .none
    var onDictatedText: ((String) -> Void)?
    
    var registered = true {
        didSet {
            if registered != oldValue {
                if registered {
                    DictationClient.clients.add(self)
                } else {
                    DictationClient.clients.remove(self)
                }
            }
        }
    }
    
    init(priority: Int? = nil) {
        self.priority = priority
        DictationClient.clients.add(self)
    }
    
    static func highestPriorityClient() -> DictationClient? {
        clients.allObjects
            .filter { $0.priority != nil }
            .max { $0.priority! < $1.priority! }
    }
}

@MainActor
class DictationManager {
    static let shared = DictationManager()
    
    private enum State {
        case idle
        case recording(client: DictationClient, recorder: AudioRecorder, liveRecognizer: LiveSpeechRecognizer)
    }
    
    private var lastFlags: NSEvent.ModifierFlags?
    private var state: State = .idle
    
    init() {
        // Monitor keyboard events globally
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                await self?.handleFlagsChanged(event)
            }
            return event
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) async {
        let flags = event.modifierFlags
        let wasCapsLockOn = lastFlags?.contains(.capsLock) ?? false
        let isCapsLockOn = flags.contains(.capsLock)
        
        if !wasCapsLockOn && isCapsLockOn {
            await startDictation()
        } else if wasCapsLockOn && !isCapsLockOn {
            await stopDictation()
        }
        
        lastFlags = flags
    }
    
    private func startDictation() async {
        guard case .idle = state else { return }
        
        guard let client = DictationClient.highestPriorityClient() else {
            return
        }
        
        guard let openAIKey = DefaultsKeys.openAIKey.stringValue().nilIfEmpty else {
            await Alerts.showAppAlert(title: "Caps Lock Dictation requires an OpenAI key", message: "Add your OpenAI API key in Settings")
            return
        }
        
        let recorder = AudioRecorder()
        client.state = .startingToRecord
        
        do {
            try await recorder.startRecording()
            
            // Start live preview recognition
            let liveRecognizer = LiveSpeechRecognizer()
            try await liveRecognizer.startRecognition { previewText in
                // Ensure we're on main queue and still in recording state
                Task { @MainActor in
                    if client.state.isRecordingOrStarting {
                        client.state = .recording(previewText: previewText)
                    }
                }
            }
            state = .recording(client: client, recorder: recorder, liveRecognizer: liveRecognizer)
        } catch {
            await Alerts.showAppAlert(title: "Recording Error", message: error.localizedDescription)
            client.state = .none
        }
    }
    
    private func stopDictation() async {
        guard case .recording(let client, let recorder, let liveRecognizer) = state else { return }
        liveRecognizer.stopRecognition()
        client.state = .recognizingSpeech
        
        do {
            let audioData = try recorder.stopRecording()
            let recognizer = OpenAISpeechRecognizer(credentials: OpenAICredentials(apiKey: DefaultsKeys.openAIKey.stringValue()))
            let transcription = try await recognizer.transcribe(audioData: audioData, format: .m4a)
            client.onDictatedText?(transcription.text)
        } catch {
            await Alerts.showAppAlert(title: "Transcription Error", message: error.localizedDescription)
        }
        
        client.state = .none
        state = .idle
    }
}
