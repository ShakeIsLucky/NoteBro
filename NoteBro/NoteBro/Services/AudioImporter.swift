import Foundation
import UniformTypeIdentifiers
import AVFoundation

enum AudioImporter {
    private static var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static let supportedTypes: [UTType] = [
        .audio,
        .mpeg4Audio,
        .mp3,
        .wav,
        .aiff,
    ]

    struct ImportedAudio {
        let localURL: URL
        let relativePath: String
        let originalName: String
        let creationDate: Date
        let duration: TimeInterval
    }

    static func importFile(from sourceURL: URL) async throws -> ImportedAudio {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let fileName = "import_\(UUID().uuidString).\(ext)"
        let destURL = recordingsDirectory.appendingPathComponent(fileName)

        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        let creationDate = fileCreationDate(for: sourceURL) ?? Date()
        let duration = await audioDuration(for: destURL)

        return ImportedAudio(
            localURL: destURL,
            relativePath: "Recordings/\(fileName)",
            originalName: originalName,
            creationDate: creationDate,
            duration: duration
        )
    }

    static func importFiles(from urls: [URL]) async throws -> [ImportedAudio] {
        var results: [ImportedAudio] = []
        for url in urls {
            let imported = try await importFile(from: url)
            results.append(imported)
        }
        return results
    }

    private static func fileCreationDate(for url: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.creationDate] as? Date
    }

    private static func audioDuration(for url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try? await asset.load(.duration)
        return duration?.seconds ?? 0
    }
}
