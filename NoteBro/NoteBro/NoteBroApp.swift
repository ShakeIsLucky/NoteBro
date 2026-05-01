import SwiftUI
import SwiftData

@main
struct NoteBroApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Meeting.self,
            ChatMessage.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
                .tint(NB.accent)
        }
        .modelContainer(sharedModelContainer)
    }
}
