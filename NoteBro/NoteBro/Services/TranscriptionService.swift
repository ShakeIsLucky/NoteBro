import Foundation

struct TranscriptSegment: Codable, Sendable {
    let start: Double
    let end: Double
    let text: String
}

struct TranscriptResult: Sendable {
    let text: String
    let segments: [TranscriptSegment]
}

@Observable
final class TranscriptionService {
    var progress: Double = 0
    var isTranscribing = false

    nonisolated func transcribe(audioURL: URL) async throws -> TranscriptResult {
        await MainActor.run { self.isTranscribing = true; self.progress = 0 }
        defer { Task { @MainActor in self.isTranscribing = false } }

        guard let apiKey = KeychainService.load(key: "openai_api_key"), !apiKey.isEmpty else {
            throw TranscriptionError.noAPIKey
        }

        let chunks = try await AudioChunker.chunkIfNeeded(audioURL: audioURL)
        defer { if chunks.count > 1 { AudioChunker.cleanupChunks(at: chunks) } }

        var allText = ""
        var allSegments: [TranscriptSegment] = []
        var timeOffset: Double = 0

        for (index, chunkURL) in chunks.enumerated() {
            let result = try await transcribeChunk(url: chunkURL, apiKey: apiKey)

            allText += (allText.isEmpty ? "" : " ") + result.text

            for segment in result.segments {
                allSegments.append(TranscriptSegment(
                    start: segment.start + timeOffset,
                    end: segment.end + timeOffset,
                    text: segment.text
                ))
            }

            if let lastSegment = result.segments.last {
                timeOffset += lastSegment.end
            }

            await MainActor.run {
                self.progress = Double(index + 1) / Double(chunks.count)
            }
        }

        return TranscriptResult(text: allText, segments: allSegments)
    }

    nonisolated private func transcribeChunk(url: URL, apiKey: String) async throws -> TranscriptResult {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: url)

        var body = Data()
        body.appendMultipart(boundary: boundary, name: "file", filename: url.lastPathComponent, mimeType: "audio/m4a", data: audioData)
        body.appendMultipart(boundary: boundary, name: "model", value: "whisper-1")
        body.appendMultipart(boundary: boundary, name: "response_format", value: "verbose_json")
        body.appendMultipart(boundary: boundary, name: "language", value: "en")
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TranscriptionError.apiError(httpResponse.statusCode, errorBody)
        }

        let decoded = try JSONDecoder().decode(WhisperResponse.self, from: data)
        let segments = decoded.segments?.map { seg in
            TranscriptSegment(start: seg.start, end: seg.end, text: seg.text)
        } ?? []

        return TranscriptResult(text: decoded.text, segments: segments)
    }

    enum TranscriptionError: LocalizedError {
        case noAPIKey
        case invalidResponse
        case apiError(Int, String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No OpenAI API key configured. Add it in Settings."
            case .invalidResponse: return "Invalid response from OpenAI."
            case .apiError(let code, let msg): return "OpenAI API error (\(code)): \(msg)"
            }
        }
    }
}

private struct WhisperResponse: Codable {
    let text: String
    let segments: [WhisperSegment]?
}

private struct WhisperSegment: Codable {
    let start: Double
    let end: Double
    let text: String
}

extension Data {
    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipart(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
