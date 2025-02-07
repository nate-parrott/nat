import Foundation
import AVFoundation

class AudioRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.m4a")
    
    override init() {
        super.init()
    }
    
    func startRecording() async throws {
        // Request permission
        let authorized = await AVCaptureDevice.requestAccess(for: .audio)
        guard authorized else {
            throw AudioRecorderError.permissionDenied
        }
        
        // Optimized settings for ASR:
        // - 16kHz sample rate (standard for most ASR)
        // - AAC compression for smaller file size
        // - Mono audio is sufficient for speech
        // - Medium quality (reduces size while maintaining speech clarity)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 32000
        ]
        
        recorder = try AVAudioRecorder(url: audioURL, settings: settings)
        guard let recorder = recorder else {
            throw AudioRecorderError.setupFailed
        }
        
        recorder.record()
    }
    
    func stopRecording() throws -> Data {
        guard let recorder = recorder else {
            throw AudioRecorderError.notRecording
        }
        
        recorder.stop()
        
        guard let data = try? Data(contentsOf: audioURL) else {
            throw AudioRecorderError.noData
        }
        
        return data
    }
}

enum AudioRecorderError: Error {
    case setupFailed
    case notRecording
    case permissionDenied
    case noData
}