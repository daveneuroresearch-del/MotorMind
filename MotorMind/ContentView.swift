import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            PracticeView()
                .tabItem { Label("Practice", systemImage: "hand.tap") }

            BrainLabView()
                .tabItem { Label("Brain Lab", systemImage: "brain.head.profile") }

            ProgressDashboardView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

            LearnView()
                .tabItem { Label("Learn", systemImage: "book") }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
        .tint(Theme.teal)
        .modelContainer(for: [ActivityResult.self, PracticeSession.self], inMemory: true)
}
