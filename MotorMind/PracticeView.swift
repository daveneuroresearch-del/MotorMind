import SwiftUI
import SwiftData
import UIKit

/// Motor-imagery practice: imagine squeezing one hand for 4 s, then rest for 3 s, repeated.
struct PracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]

    @ScaledMetric(relativeTo: .largeTitle) private var arrowSize: CGFloat = 110

    // Timing
    private static let imagineSeconds: Double = 4
    private static let restSeconds: Double = 3
    private static let trialSeconds = imagineSeconds + restSeconds
    private static let durationOptions = [2, 5, 10]

    private enum Cue: Equatable {
        case imagine(Hand)
        case rest
    }

    // Setup
    @State private var selectedMinutes = 5

    // Running session
    @State private var isRunning = false
    @State private var cue: Cue = .rest
    @State private var cueStart = Date()
    @State private var cueDuration: Double = PracticeView.imagineSeconds
    @State private var cueChanges = 0
    @State private var trialIndex = 0
    @State private var totalTrials = 0
    @State private var sessionStart = Date()
    @State private var runTask: Task<Void, Never>?

    // Last result
    @State private var lastCompleted: (minutes: Int, trials: Int)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    statsHeader

                    if isRunning {
                        sessionView
                        Button("Stop Session", action: stop)
                            .buttonStyle(.secondary)
                    } else {
                        if let done = lastCompleted {
                            completedCard(done)
                        }
                        introCard
                        durationPicker
                        Button("Start \(selectedMinutes)-Minute Session", action: start)
                            .buttonStyle(.primary)
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.25), value: isRunning)
            }
            .screenStyle()
            .navigationTitle("Practice")
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: cueChanges)
    }

    // MARK: - Header

    private var statsHeader: some View {
        HStack(spacing: 12) {
            statTile(
                icon: "clock",
                title: "Today",
                value: "\(PracticeSession.minutesToday(in: sessions)) min"
            )
            let streak = PracticeSession.currentStreak(in: sessions)
            statTile(
                icon: "flame",
                title: "Streak",
                value: "\(streak) \(streak == 1 ? "day" : "days")"
            )
        }
    }

    private func statTile(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.title.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Setup

    private var introCard: some View {
        Card {
            Text("Motor Imagery")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("An arrow shows which hand to focus on. Picture squeezing that hand as clearly as you can without moving it, then relax when you see Rest.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session length")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 12) {
                ForEach(Self.durationOptions, id: \.self) { minutes in
                    let selected = minutes == selectedMinutes
                    Button {
                        selectedMinutes = minutes
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(minutes)")
                                .font(.largeTitle.weight(.bold))
                                .monospacedDigit()
                            Text("min")
                                .font(.headline)
                            Text("\(Self.trialCount(for: minutes)) trials")
                                .font(.footnote)
                                .opacity(0.8)
                        }
                        .foregroundStyle(selected ? Theme.navy : Theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 110)
                        .padding(.vertical, 8)
                        .background(
                            selected ? Theme.teal : Theme.surface,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(minutes) minutes, \(Self.trialCount(for: minutes)) trials")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private func completedCard(_ done: (minutes: Int, trials: Int)) -> some View {
        Card {
            Label("Session complete", systemImage: "checkmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.teal)
            Text("\(done.minutes) minutes · \(done.trials) trials. Saved to your history.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Running session

    private var sessionView: some View {
        TimelineView(.animation) { context in
            let now = context.date
            let cueProgress = min(1, max(0, now.timeIntervalSince(cueStart) / cueDuration))
            let totalSeconds = Double(totalTrials) * Self.trialSeconds
            let remaining = max(0, totalSeconds - now.timeIntervalSince(sessionStart))

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Theme.surfaceRaised, lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: cueProgress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    cueSymbol
                }
                .frame(maxWidth: 280)
                .aspectRatio(1, contentMode: .fit)
                .padding(.top, 8)
                .accessibilityHidden(true)

                cueText
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.updatesFrequently)

                HStack {
                    Text("Trial \(trialIndex + 1) of \(totalTrials)")
                    Spacer()
                    Text(Self.clock(remaining) + " left")
                }
                .font(.title3.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
            }
            .padding(20)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    private var ringColor: Color {
        if case .imagine = cue { return Theme.teal }
        return Theme.textSecondary.opacity(0.6)
    }

    @ViewBuilder
    private var cueSymbol: some View {
        switch cue {
        case .imagine(let hand):
            Image(systemName: hand == .left ? "arrow.left" : "arrow.right")
                .font(.system(size: min(arrowSize, 150), weight: .bold))
                .foregroundStyle(Theme.teal)
                .transition(.opacity)
        case .rest:
            Image(systemName: "pause")
                .font(.system(size: min(arrowSize, 150) * 0.6, weight: .regular))
                .foregroundStyle(Theme.textSecondary.opacity(0.6))
                .transition(.opacity)
        }
    }

    private var cueText: Text {
        switch cue {
        case .imagine(let hand):
            let side = Text(hand.rawValue.uppercased()).foregroundColor(Theme.teal)
            return Text("Imagine squeezing your \(side) hand")
        case .rest:
            return Text("Rest")
        }
    }

    // MARK: - Logic

    private func start() {
        let minutes = selectedMinutes
        let trials = Self.trialCount(for: minutes)
        let sequence = Self.balancedSequence(count: trials)

        runTask?.cancel()
        lastCompleted = nil
        totalTrials = trials
        trialIndex = 0
        sessionStart = Date()
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true

        runTask = Task { @MainActor in
            for (index, hand) in sequence.enumerated() {
                trialIndex = index

                show(.imagine(hand), for: Self.imagineSeconds)
                try? await Task.sleep(for: .seconds(Self.imagineSeconds))
                if Task.isCancelled { return }

                show(.rest, for: Self.restSeconds)
                try? await Task.sleep(for: .seconds(Self.restSeconds))
                if Task.isCancelled { return }
            }
            complete(minutes: minutes, trials: trials)
        }
    }

    private func show(_ newCue: Cue, for seconds: Double) {
        withAnimation(.easeInOut(duration: 0.2)) {
            cue = newCue
        }
        cueStart = Date()
        cueDuration = seconds
        cueChanges += 1

        let announcement: String
        switch newCue {
        case .imagine(let hand): announcement = "Imagine squeezing your \(hand.rawValue.lowercased()) hand"
        case .rest: announcement = "Rest"
        }
        AccessibilityNotification.Announcement(announcement).post()
    }

    private func complete(minutes: Int, trials: Int) {
        modelContext.insert(PracticeSession(date: .now, minutes: minutes, trials: trials))
        try? modelContext.save()
        lastCompleted = (minutes, trials)
        cueChanges += 1
        endSession()
    }

    private func stop() {
        runTask?.cancel()
        endSession()
    }

    private func endSession() {
        runTask = nil
        isRunning = false
        cue = .rest
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Helpers

    /// Number of full 7-second trials that fit in the chosen length (2 → 17, 5 → 42, 10 → 85).
    static func trialCount(for minutes: Int) -> Int {
        Int(Double(minutes * 60) / trialSeconds)
    }

    /// Equal numbers of left and right in random order. With an odd count, the extra side is random.
    static func balancedSequence(count: Int) -> [Hand] {
        let half = count / 2
        var sequence = Array(repeating: Hand.left, count: half) + Array(repeating: Hand.right, count: half)
        if count % 2 == 1 {
            sequence.append(Bool.random() ? .left : .right)
        }
        return sequence.shuffled()
    }

    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#Preview {
    PracticeView()
        .preferredColorScheme(.dark)
        .tint(Theme.teal)
        .modelContainer(for: [ActivityResult.self, PracticeSession.self], inMemory: true)
}
