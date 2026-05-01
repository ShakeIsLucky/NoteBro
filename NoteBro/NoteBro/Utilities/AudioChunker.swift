import Foundation
import AVFoundation

enum AudioChunker {
    static let maxChunkSize: Int = 24 * 1024 * 1024 // 24MB to stay safely under Whisper's 25MB limit

    static func chunkIfNeeded(audioURL: URL) async throws -> [URL] {
        let fileSize = try FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int ?? 0

        if fileSize <= maxChunkSize {
            return [audioURL]
        }

        let asset = AVURLAsset(url: audioURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)
        let chunkCount = Int(ceil(Double(fileSize) / Double(maxChunkSize)))
        let chunkDuration = totalSeconds / Double(chunkCount)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("notebro_chunks_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var chunkURLs: [URL] = []

        for i in 0..<chunkCount {
            let startTime = CMTime(seconds: Double(i) * chunkDuration, preferredTimescale: 600)
            let endSeconds = min(Double(i + 1) * chunkDuration, totalSeconds)
            let timeRange = CMTimeRange(
                start: startTime,
                duration: CMTime(seconds: endSeconds - CMTimeGetSeconds(startTime), preferredTimescale: 600)
            )

            let chunkURL = tempDir.appendingPathComponent("chunk_\(i).m4a")

            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                throw ChunkerError.exportSessionFailed
            }

            exportSession.outputURL = chunkURL
            exportSession.outputFileType = .m4a
            exportSession.timeRange = timeRange

            await exportSession.export()

            guard exportSession.status == .completed else {
                throw ChunkerError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
            }

            chunkURLs.append(chunkURL)
        }

        return chunkURLs
    }

    static func cleanupChunks(at urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
        if let first = urls.first {
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
        }
    }

    enum ChunkerError: LocalizedError {
        case exportSessionFailed
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .exportSessionFailed: return "Could not create audio export session"
            case .exportFailed(let msg): return "Audio chunk export failed: \(msg)"
            }
        }
    }
}
