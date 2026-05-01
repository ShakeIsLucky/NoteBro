import Foundation
import SwiftData

@Model
final class Meeting {
    var id: UUID = UUID()
    var name: String = ""
    var date: Date = Date()
    var duration: TimeInterval = 0
    var meetingType: String = MeetingType.automatic.rawValue
    var status: String = MeetingStatus.recording.rawValue
    var audioFileURL: String?
    var transcript: String?
    var summary: String?
    var markdownNotes: String?
    var obsidianExported: Bool = false
    var customPrompt: String?
    var participants: [String] = []
    var tags: [String] = []

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.meeting)
    var chatMessages: [ChatMessage] = []

    init(
        name: String,
        date: Date = Date(),
        meetingType: MeetingType = .automatic,
        status: MeetingStatus = .recording
    ) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.meetingType = meetingType.rawValue
        self.status = status.rawValue
    }

    var meetingTypeEnum: MeetingType {
        get { MeetingType(rawValue: meetingType) ?? .automatic }
        set { meetingType = newValue.rawValue }
    }

    var statusEnum: MeetingStatus {
        get { MeetingStatus(rawValue: status) ?? .recording }
        set { status = newValue.rawValue }
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(minutes)m \(seconds)s"
    }

    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    var audioFileFullURL: URL? {
        guard let relativePath = audioFileURL else { return nil }
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return documentsDir.appendingPathComponent(relativePath)
    }
}
