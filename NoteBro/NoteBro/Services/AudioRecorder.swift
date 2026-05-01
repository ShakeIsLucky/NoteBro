import AVFoundation
import Foundation

@MainActor
@Observable
final class AudioRecorder: NSObject {
    var isRecording = false
    var isPaused = false
    var currentPower: Float = 0
    var elapsedTime: TimeInterval = 0
    var recordingURL: URL?
    var permissionGranted = false

    private var recorder: AVAudioRecorder?
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
        guard !isRecording else { return }
        guard await requestPermission() else {
            throw RecorderError.permissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let fileName = "recording_\(UUID().uuidString).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder.isMeteringEnabled = true
        audioRecorder.prepareToRecord()

        guard audioRecorder.record() else {
            throw RecorderError.startFailed
        }

        recorder = audioRecorder
        recordingURL = fileURL
        isRecording = true
        isPaused = false
        currentPower = 0
        elapsedTime = 0
        pausedDuration = 0
        pauseStart = nil
        startTime = Date()

        startMeterTimer()
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        isPaused = false
        currentPower = 0
        pauseStart = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return recordingURL
    }

    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        recorder?.pause()
        isPaused = true
        currentPower = 0
        pauseStart = Date()
    }

    func resumeRecording() {
        guard isRecording, isPaused else { return }
        if let pauseStart {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        recorder?.record()
        isPaused = false
        pauseStart = nil
    }

    var relativeRecordingPath: String? {
        guard let url = recordingURL else { return nil }
        return "Recordings/\(url.lastPathComponent)"
    }

    private func startMeterTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard self.isRecording, let start = self.startTime else { return }

                if !self.isPaused {
                    self.elapsedTime = Date().timeIntervalSince(start) - self.pausedDuration
                    self.recorder?.updateMeters()
                    let averagePower = self.recorder?.averagePower(forChannel: 0) ?? -80
                    self.currentPower = Self.normalizedPower(fromDecibels: averagePower)
                }
            }
        }
    }

    private static func normalizedPower(fromDecibels decibels: Float) -> Float {
        guard decibels > -80 else { return 0 }
        return min(max((decibels + 80) / 80, 0), 1)
    }

    enum RecorderError: LocalizedError {
        case permissionDenied
        case startFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "Microphone access is required to record meetings."
            case .startFailed:
                "Recording could not be started. Please try again."
            }
        }
    }
}
