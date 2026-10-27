import SwiftUI

struct LearnTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let summary: String
    let paragraphs: [String]
}

extension LearnTopic {
    static let all: [LearnTopic] = [
        LearnTopic(
            id: "motor-learning",
            title: "What Is Motor Learning?",
            icon: "figure.walk",
            summary: "How practice turns clumsy movements into smooth, automatic ones.",
            paragraphs: [
                "Motor learning is the way your brain gets better at controlling movement through practice. Think about learning to ride a bike or type on a keyboard: at first every movement takes focus, but over time it becomes automatic.",
                "Scientists often describe it in stages. Early on you think about each step and make lots of small mistakes. With repetition and feedback, your movements get faster, more accurate, and need less attention.",
            ]
        ),
        LearnTopic(
            id: "neuroplasticity",
            title: "Neuroplasticity",
            icon: "brain",
            summary: "Your brain can rewire itself based on what you practice.",
            paragraphs: [
                "Neuroplasticity is the brain's ability to change its connections. When you practice a skill, the pathways between the neurons involved get stronger and more efficient.",
                "This is why consistent practice matters, and it is also part of how people can regain skills after an injury with the help of therapy.",
            ]
        ),
        LearnTopic(
            id: "reaction-time",
            title: "Understanding Reaction Time",
            icon: "bolt",
            summary: "The gap between seeing a signal and responding to it.",
            paragraphs: [
                "Reaction time is how long it takes you to notice something and respond, like the time between a light turning green and your foot leaving the brake.",
                "Your reaction time naturally changes from day to day. Sleep, focus, caffeine, stress, and even the device you're using can all make a difference, so look at trends over many tries instead of a single number.",
            ]
        ),
        LearnTopic(
            id: "practice-tips",
            title: "Tips for Better Practice",
            icon: "lightbulb",
            summary: "Small habits that help skills stick.",
            paragraphs: [
                "Short, regular sessions usually work better than one long session. A few minutes a day keeps your brain engaged without getting tired.",
                "Rest matters too. Much of the strengthening happens between sessions, especially during sleep. Track your results so you can see improvement over weeks, not just minutes.",
            ]
        ),
        LearnTopic(
            id: "about",
            title: "About MotorMind",
            icon: "info.circle",
            summary: "What this app is, and what it isn't.",
            paragraphs: [
                "MotorMind is a practice and learning tool built for the Congressional App Challenge. It helps you explore motor skills and reaction time in a fun, measurable way.",
                "MotorMind is not a medical device and doesn't diagnose anything. If you're worried about your movement or coordination, talk with a doctor or therapist.",
            ]
        ),
    ]
}

struct LearnView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(LearnTopic.all) { topic in
                        NavigationLink(value: topic) {
                            topicRow(topic)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .screenStyle()
            .navigationTitle("Learn")
            .navigationDestination(for: LearnTopic.self) { topic in
                LearnDetailView(topic: topic)
            }
        }
    }

    private func topicRow(_ topic: LearnTopic) -> some View {
        HStack(spacing: 16) {
            Image(systemName: topic.icon)
                .font(.title)
                .foregroundStyle(Theme.teal)
                .frame(width: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(topic.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(topic.summary)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
    }
}

struct LearnDetailView: View {
    let topic: LearnTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: topic.icon)
                    .font(.system(.largeTitle))
                    .foregroundStyle(Theme.teal)
                    .accessibilityHidden(true)

                ForEach(topic.paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.title3)
                        .lineSpacing(6)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .screenStyle()
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    LearnView()
        .preferredColorScheme(.dark)
}
