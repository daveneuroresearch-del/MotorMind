import Foundation
import SwiftData

enum ActivityKind: String, CaseIterable, Identifiable {
    case tapping
    case reaction

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tapping: return "Finger Tapping"
        case .reaction: return "Reaction Time"
        }
    }

    var unit: String {
        switch self {
        case .tapping: return "taps"
        case .reaction: return "ms"
        }
    }

    var icon: String {
        switch self {
        case .tapping: return "hand.tap"
        case .reaction: return "bolt"
        }
    }

    /// More taps is better; a lower reaction time is better.
    var higherIsBetter: Bool { self == .tapping }
}

enum Hand: String, CaseIterable, Identifiable {
    case left = "Left"
    case right = "Right"

    var id: String { rawValue }
}

/// One finished motor-imagery practice session.
@Model
final class PracticeSession {
    var date: Date
    var minutes: Int
    var trials: Int

    init(date: Date = .now, minutes: Int, trials: Int) {
        self.date = date
        self.minutes = minutes
        self.trials = trials
    }
}

extension PracticeSession {
    /// Total minutes practiced on the same calendar day as `now`.
    static func minutesToday(in sessions: [PracticeSession], calendar: Calendar = .current, now: Date = .now) -> Int {
        sessions
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .reduce(0) { $0 + $1.minutes }
    }

    /// Consecutive days with at least one session, counting back from today.
    /// If today has no session yet, the streak is still alive when yesterday has one.
    static func currentStreak(in sessions: [PracticeSession], calendar: Calendar = .current, now: Date = .now) -> Int {
        let practiceDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: now)

        if !practiceDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  practiceDays.contains(yesterday) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while practiceDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}

/// One saved result from Brain Lab.
@Model
final class ActivityResult {
    var date: Date
    var kindRaw: String
    var score: Double
    var hand: String

    init(kind: ActivityKind, score: Double, hand: String = "", date: Date = .now) {
        self.date = date
        self.kindRaw = kind.rawValue
        self.score = score
        self.hand = hand
    }

    var kind: ActivityKind {
        ActivityKind(rawValue: kindRaw) ?? .tapping
    }
}
