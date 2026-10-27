import SwiftUI
import SwiftData

@main
struct MotorMindApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .tint(Theme.teal)
        }
        .modelContainer(for: [ActivityResult.self, PracticeSession.self])
    }
}
