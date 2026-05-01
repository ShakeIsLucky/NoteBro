import Foundation
import SwiftUI

enum ObsidianExporter {
    static func export(meeting: Meeting) throws {
        let markdown = generateMarkdown(for: meeting)
        meeting.markdownNotes = markdown

        guard let bookmarkData = UserDefaults.standard.data(forKey: "obsidianVaultBookmark") else {
            throw ExportError.noVaultConfigured
        }

        var isStale = false
        let vaultURL = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)

        guard vaultURL.startAccessingSecurityScopedResource() else {
            throw ExportError.accessDenied
        }
        defer { vaultURL.stopAccessingSecurityScopedResource() }

        let dateStr = meeting.date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let safeName = meeting.name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let fileName = "\(dateStr) \(safeName).md"
        let fileURL = vaultURL.appendingPathComponent(fileName)

        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        meeting.obsidianExported = true
    }

    static func generateMarkdown(for meeting: Meeting) -> String {
        let dateStr = meeting.date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let participantsList = meeting.participants.map { "  - \($0)" }.joined(separator: "\n")
        let tagsList = meeting.tags.map { "  - \($0)" }.joined(separator: "\n")

        var md = """
        ---
        date: \(dateStr)
        duration: \(meeting.formattedDuration)
        meeting_type: \(meeting.meetingTypeEnum.displayName)
        participants:
        \(participantsList.isEmpty ? "  - (none recorded)" : participantsList)
        tags:
        \(tagsList.isEmpty ? "  - meeting" : tagsList)
        ---

        # \(meeting.name)

        > \(meeting.formattedDate) · \(meeting.formattedDuration) · \(meeting.meetingTypeEnum.displayName)

        """

        if let summary = meeting.summary, !summary.isEmpty {
            let links = WikilinkGenerator.extractLinks(from: summary)
            let linkedSummary = WikilinkGenerator.applyWikilinks(to: summary, links: links)
            md += "\n\(linkedSummary)\n"
        } else {
            md += "\n*No summary generated yet.*\n"
        }

        if let transcript = meeting.transcript, !transcript.isEmpty {
            md += """

            ---

            <details>
            <summary>Full Transcript</summary>

            \(transcript)

            </details>

            """
        }

        return md
    }

    enum ExportError: LocalizedError {
        case noVaultConfigured
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .noVaultConfigured: return "No Obsidian vault selected. Configure it in Settings."
            case .accessDenied: return "Cannot access the Obsidian vault folder. Please re-select it in Settings."
            }
        }
    }
}
