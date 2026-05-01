import AVFoundation
import Foundation

@Observable
final class AudioRecorder {
    var isRecording = false
    var isPaused = false
    var currentPower: Float = 0
    var elapsedTime: TimeInterval = 0
    var recordingURL: URL?
    var permissionGranted = false

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var timer: Timer?
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStart: Date?

    private var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            let granted = await AVAudioApplication.requestRecordPermission()
            permissionGranted = granted
            return granted
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor in
                        self.permissionGranted = granted
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func startRecording() async throws {
        guard await requestPermission() else {
            throw RecorderError.permissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let fileName = "recording_\(UUID().uuidString).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let file = try AVAudioFile(forWriting: fileURL, settings: outputSettings)

        let monoFormat = AVAudioFormat(
            standardFormatWithSampleRate: inputFormat.sampleRate,
            channels: 1
        )!

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: monoFormat) { [weak self] buffer, _ in
            guard let self else { return }
            if !self.isPaused {
                try? file.write(from: buffer)
            }

            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            var rms: Float = 0
            if let data = channelData, frameLength > 0 {
                var sum: Float = 0
                for i in 0..<frameLength {
                    sum += data[i] * data[i]
                }
                rms = sqrtf(sum / Float(frameLength))
            }
            let normalized = min(rms * 5, 1.0)

            Task { @MainActor in
                self.currentPower = normalized
            }
        }

        try engine.start()

        audioEngine = engine
        audioFile = file
        recordingURL = fileURL
        isRecording = true
        isPaused = false
        startTime = Date()
        pausedDuration = 0
        elapsedTime = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.startTime else { return }
            if !self.isPaused {
                self.elapsedTime = Date().timeIntervalSince(start) - self.pausedDuration
            }
        }
    }

    func stopRecording() -> URL? {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        isPaused = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return recordingURL
    }

    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        isPaused = true
        pauseStart = Date()
        audioEngine?.pause()
    }

    func resumeRecording() {
        guard isRecording, isPaused else { return }
        if let pauseStart {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        isPaused = false
        pauseStart = nil
        try? audioEngine?.start()
    }

    var relativeRecordingPath: String? {
        guard let url = recordingURL else { return nil }
        return "Recordings/\(url.lastPathComponent)"
    }

    enum RecorderError: LocalizedError {
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .permissionDenied: "Microphone access is required to record meetings."
            }
        }
    }
}
