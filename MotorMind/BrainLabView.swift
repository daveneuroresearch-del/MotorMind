import SwiftUI
import Charts

/// Explainable decoder: log-variance features + LDA, evaluated leave-one-participant-out
/// on the bundled BNCI2014-001 trials.
struct BrainLabView: View {
    @State private var report: DecoderReport?
    @State private var loadError: String?
    @State private var selectedIndex = 0
    @State private var perturbations = Perturbations()

    private static let plottedChannels = ["C3", "Cz", "C4"]

    var body: some View {
        NavigationStack {
            Group {
                if let report {
                    content(report)
                } else if let loadError {
                    ContentUnavailableView(
                        "Couldn't Load EEG Data",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(Theme.teal)
                        Text("Training the decoder…")
                            .font(.title3)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .screenStyle()
            .navigationTitle("Brain Lab")
        }
        .task {
            guard report == nil else { return }
            do {
                report = try await Task.detached(priority: .userInitiated) {
                    try BrainLabDecoder.run()
                }.value
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    // MARK: - Content

    private func content(_ report: DecoderReport) -> some View {
        let trials = report.dataset.trials
        let index = min(selectedIndex, max(trials.count - 1, 0))

        return ScrollView {
            VStack(spacing: 20) {
                accuracyCard(report)

                if trials.indices.contains(index) {
                    let trial = trials[index]
                    trialSelector(trial: trial, index: index, count: trials.count)

                    if let prediction = report.predictions[trial.id] {
                        predictionCard(trial: trial, prediction: prediction)
                        signalsCard(trial: trial, sampleRate: report.dataset.sampleRate)
                        headMapCard(trial: trial, prediction: prediction)
                        TrustCheckPanel(
                            trial: trial,
                            prediction: prediction,
                            model: report.models[trial.participant],
                            sampleRate: report.dataset.sampleRate,
                            perturbations: $perturbations
                        )
                    }
                }

                methodCard(report)
            }
            .padding()
        }
    }

    // MARK: - Accuracy

    private func accuracyCard(_ report: DecoderReport) -> some View {
        Card {
            Text("Leave-one-participant-out accuracy")
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)
            Text(report.accuracy, format: .percent.precision(.fractionLength(1)))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("\(report.correct) of \(report.total) trials correct · chance is 50%")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 8) {
                ForEach(report.participantScores) { score in
                    VStack(spacing: 2) {
                        Text("P\(score.participant)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Text("\(score.correct)/\(score.total)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Participant \(score.participant): \(score.correct) of \(score.total) correct")
                }
            }
        }
    }

    // MARK: - Trial selector

    private func trialSelector(trial: EEGTrial, index: Int, count: Int) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Trial \(index + 1) of \(count)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Participant \(trial.participant) · Actual: \(trial.label.displayName) hand")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)

            HStack(spacing: 12) {
                Button {
                    selectedIndex = (index - 1 + count) % count
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .buttonStyle(.secondary)

                Button {
                    selectedIndex = (index + 1) % count
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(.primary)
            }
        }
    }

    // MARK: - Prediction

    private func predictionCard(trial: EEGTrial, prediction: TrialPrediction) -> some View {
        let isCorrect = prediction.predicted == trial.label
        let handColor = prediction.predicted == .right ? Theme.teal : Theme.amber

        return Card {
            HStack(alignment: .firstTextBaseline) {
                Text("Predicted")
                    .font(.headline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Label(isCorrect ? "Correct" : "Incorrect",
                      systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(isCorrect ? Theme.teal : Theme.textSecondary)
            }

            HStack(spacing: 14) {
                Image(systemName: prediction.predicted == .left ? "arrow.left" : "arrow.right")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(handColor)
                    .accessibilityHidden(true)
                Text("\(prediction.predicted.displayName.uppercased()) hand")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.7)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Confidence")
                    Spacer()
                    Text(prediction.confidence, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                }
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

                ProgressView(value: prediction.confidence, total: 1)
                    .tint(handColor)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .accessibilityHidden(true)
            }

            Text("Tested by a model trained without participant \(prediction.trainedWithoutParticipant).")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Signals

    private func signalsCard(trial: EEGTrial, sampleRate: Double) -> some View {
        let series = Self.plottedChannels.compactMap { name -> (String, [Float])? in
            trial.samples(for: name).map { (name, $0) }
        }
        let peak = Double(series.flatMap(\.1).map(abs).max() ?? 1)
        let limit = max(peak, 1)

        return Card {
            Text("Motor cortex signals")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("4 seconds after the cue, filtered 4–40 Hz. C3 sits over the left hemisphere (controls the right hand), C4 over the right.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)

            ForEach(series, id: \.0) { item in
                ChannelChart(name: item.0, samples: item.1, sampleRate: sampleRate, limit: limit)
            }

            Text("Seconds after cue")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Head map

    private func headMapCard(trial: EEGTrial, prediction: TrialPrediction) -> some View {
        Card {
            Text("Why the decoder decided")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Each circle is a sensor seen from above, nose at the top. Bigger circles mattered more for this trial.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)

            HeadMapView(channelNames: trial.channelNames, contributions: prediction.contributions)
                .frame(maxWidth: 360)
                .frame(maxWidth: .infinity)

            HStack(spacing: 20) {
                legendDot(color: Theme.amber, text: "Toward LEFT")
                legendDot(color: Theme.teal, text: "Toward RIGHT")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 14, height: 14)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: - Method

    private func methodCard(_ report: DecoderReport) -> some View {
        Card {
            Text("How it works")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("For each of the \(report.dataset.channelNames.count) sensors, the decoder measures the signal's power as log-variance. When you imagine moving a hand, power over the opposite side of the brain usually drops. A linear discriminant analysis (LDA) learns one weight per sensor from the other participants, then adds up weight × feature to choose left or right.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
            Text("Each participant is tested by a model that never saw their data, so the accuracy shows how well it works on a new person.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: - Channel chart

private struct ChannelChart: View {
    let name: String
    let samples: [Float]
    let sampleRate: Double
    let limit: Double

    private var color: Color {
        switch name {
        case "C3": return Theme.teal
        case "C4": return Theme.amber
        default: return Theme.textSecondary
        }
    }

    private var points: [(time: Double, value: Double)] {
        samples.enumerated().map { (Double($0.offset) / sampleRate, Double($0.element)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
                .foregroundStyle(color)

            Chart(points, id: \.time) { point in
                LineMark(
                    x: .value("Seconds", point.time),
                    y: .value("µV", point.value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.2))
            }
            .chartXScale(domain: 0...(Double(samples.count - 1) / sampleRate))
            .chartYScale(domain: -limit...limit)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: 1))
            }
            .frame(height: 110)
            .accessibilityLabel("\(name) signal")
            .accessibilityValue("Peak \(Int(samples.map(abs).max() ?? 0)) microvolts")
        }
    }
}

// MARK: - Helpers

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.title
            configuration.icon
        }
    }
}

extension EEGTrial.Label {
    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

#Preview {
    BrainLabView()
        .preferredColorScheme(.dark)
        .tint(Theme.teal)
}
