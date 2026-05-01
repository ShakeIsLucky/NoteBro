import Foundation

@Observable
final class SummarizationService {
    var isSummarizing = false
    var streamedContent = ""

    @ObservationIgnored
    private var modelId: String {
        UserDefaults.standard.string(forKey: "defaultModel") ?? "anthropic/claude-sonnet-4-6"
    }

    nonisolated func summarize(transcript: String, meetingType: MeetingType, customPrompt: String? = nil) async throws -> String {
        await MainActor.run { self.isSummarizing = true; self.streamedContent = "" }
        defer { Task { @MainActor in self.isSummarizing = false } }

        let systemPrompt = customPrompt ?? meetingType.promptTemplate
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": transcript]
        ]

        return try await sendChatRequest(messages: messages)
    }

    nonisolated func chat(messages: [(role: String, content: String)], systemPrompt: String) async throws -> String {
        var apiMessages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for msg in messages {
            apiMessages.append(["role": msg.role, "content": msg.content])
        }
        return try await sendChatRequest(messages: apiMessages)
    }

    nonisolated private func sendChatRequest(messages: [[String: String]]) async throws -> String {
        guard let apiKey = KeychainService.load(key: "openrouter_api_key"), !apiKey.isEmpty else {
            throw SummarizationError.noAPIKey
        }

        let model = await MainActor.run { self.modelId }

        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://notebro.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("NoteBro", forHTTPHeaderField: "X-Title")

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SummarizationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await line in asyncBytes.lines { errorBody += line }
            throw SummarizationError.apiError(httpResponse.statusCode, errorBody)
        }

        var accumulated = ""

        for try await line in asyncBytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            if jsonStr == "[DONE]" { break }

            guard let data = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else { continue }

            accumulated += content
            let snapshot = accumulated
            await MainActor.run { self.streamedContent = snapshot }
        }

        return accumulated
    }

    enum SummarizationError: LocalizedError {
        case noAPIKey
        case invalidResponse
        case apiError(Int, String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No OpenRouter API key configured. Add it in Settings."
            case .invalidResponse: return "Invalid response from OpenRouter."
            case .apiError(let code, let msg): return "OpenRouter API error (\(code)): \(msg)"
            }
        }
    }
}
