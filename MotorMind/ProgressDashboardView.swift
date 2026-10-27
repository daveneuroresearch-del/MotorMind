import SwiftUI
import SwiftData
import Charts

/// Charts and history for every saved result.
/// (Named "ProgressDashboardView" so it doesn't clash with SwiftUI's built-in ProgressView.)
struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityResult.date) private var results: [ActivityResult]
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            Group {
                if results.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Finish a Practice or Brain Lab test and your progress will show up here.")
                    )
                    .foregroundStyle(Theme.textSecondary)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            ForEach(ActivityKind.allCases) { kind in
                                let items = results.filter { $0.kind == kind }
                                if !items.isEmpty {
                                    chartCard(kind: kind, items: items)
                                }
                            }

                            recentCard

                            Button("Clear History", role: .destructive) {
                                confirmClear = true
                            }
                            .buttonStyle(.secondary)
                        }
                        .padding()
                    }
                }
            }
            .screenStyle()
            .navigationTitle("Progress")
            .confirmationDialog(
                "Delete all saved results?",
                isPresented: $confirmClear,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    try? modelContext.delete(model: ActivityResult.self)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    // MARK: Pieces

    private func chartCard(kind: ActivityKind, items: [ActivityResult]) -> some View {
        let scores = items.map(\.score)
        let best = kind.higherIsBetter ? (scores.max() ?? 0) : (scores.min() ?? 0)
        let average = scores.reduce(0, +) / Double(scores.count)

        return Card {
            Label(kind.title, systemImage: kind.icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 12) {
                statTile(title: "Best", value: "\(Int(best)) \(kind.unit)")
                statTile(title: "Average", value: "\(Int(average)) \(kind.unit)")
            }

            Chart(items) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value(kind.unit, item.score)
                )
                .foregroundStyle(Theme.teal)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", item.date),
                    y: .value(kind.unit, item.score)
                )
                .foregroundStyle(Theme.teal)
            }
            .frame(height: 200)
            .accessibilityLabel("\(kind.title) chart")

            Text(kind.higherIsBetter ? "Higher is better." : "Lower is better.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var recentCard: some View {
        Card {
            Text("Recent Sessions")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            ForEach(results.suffix(10).reversed()) { item in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.kind.title + (item.hand.isEmpty ? "" : " · \(item.hand)"))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(item.date, format: .dateTime.month().day().hour().minute())
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Text("\(Int(item.score)) \(item.kind.unit)")
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.teal)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview {
    ProgressDashboardView()
        .preferredColorScheme(.dark)
        .modelContainer(for: ActivityResult.self, inMemory: true)
}
