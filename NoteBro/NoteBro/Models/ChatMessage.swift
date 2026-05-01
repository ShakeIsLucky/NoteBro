import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var role: String = "user"
    var content: String = ""
    var timestamp: Date = Date()
    var meeting: Meeting?

    init(role: String, content: String, meeting: Meeting? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.meeting = meeting
    }
}
