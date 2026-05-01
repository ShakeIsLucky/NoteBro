import Foundation

@Observable
final class AgentService {
    var isProcessing = false
    var history: [(role: String, content: String)] = []

    private let summarizer = SummarizationService()

    var streamedContent: String { summarizer.streamedContent }

    func sendMessage(_ text: String, meeting: Meeting?, allMeetings: [Meeting]) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }

        history.append((role: "user", content: text))

        let systemPrompt = buildSystemPrompt(meeting: meeting, allMeetings: allMeetings)
        let response = try await summarizer.chat(messages: history, systemPrompt: systemPrompt)

        history.append((role: "assistant", content: response))
        return response
    }

    func clearHistory() {
        history.removeAll()
    }

    private func buildSystemPrompt(meeting: Meeting?, allMeetings: [Meeting]) -> String {
        if let meeting = meeting {
            return singleMeetingPrompt(meeting)
        }
        return crossMeetingPrompt(allMeetings)
    }

    private func singleMeetingPrompt(_ meeting: Meeting) -> String {
        var prompt = """
        You are NoteBro, an AI assistant for meeting notes. You are helping the user with a specific meeting.

        Meeting: \(meeting.name)
        Date: \(meeting.formattedDate)
        Duration: \(meeting.formattedDuration)
        Type: \(meeting.meetingTypeEnum.displayName)
        """

        if let summary = meeting.summary {
            prompt += "\n\nCurrent Summary:\n\(summary)"
        }

        if let transcript = meeting.transcript {
            let truncated = transcript.count > 50000 ? String(transcript.prefix(50000)) + "\n\n[Transcript truncated]" : transcript
            prompt += "\n\nTranscript:\n\(truncated)"
        }

        prompt += """

        \nHelp the user understand, modify, or extract information from this meeting. When they ask you to update the summary or action items, format your response with clear Markdown sections (## Summary, ## Key Takeaways, ## Action Items) so the changes can be applied.
        """

        return prompt
    }

    private func crossMeetingPrompt(_ meetings: [Meeting]) -> String {
        var prompt = """
        You are NoteBro, an AI assistant for meeting notes. The user is searching across all their meetings.

        Meeting Index (\(meetings.count) meetings):
        """

        for meeting in meetings.prefix(50) {
            let preview = meeting.summary?.prefix(200) ?? "(no summary)"
            prompt += "\n- [\(meeting.formattedDate)] \(meeting.name) (\(meeting.meetingTypeEnum.displayName)): \(preview)"
        }

        prompt += """

        \nHelp the user find information across their meetings. If they ask about a specific topic, reference the relevant meetings by name and date. Be concise and helpful.
        """

        return prompt
    }
}
