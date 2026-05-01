import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Library", systemImage: "book.fill") {
                MeetingListView()
            }

            Tab("Record", systemImage: "mic.fill") {
                RecordView()
            }

            Tab("Chat", systemImage: "bubble.left.and.bubble.right.fill") {
                AgentChatView()
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(NB.accent)
        .toolbarBackground(NB.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
