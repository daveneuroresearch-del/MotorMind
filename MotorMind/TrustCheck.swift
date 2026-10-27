import SwiftUI

// Trust Check: perturb one trial, re-run the SAME fold model (no retraining), and ask
//   1. Is the predicted hand preserved?
//   2. Is the explanation stable? Spearman rank correlation between the original and
//      perturbed per-channel contributions (wᵢ·zᵢ). Above 0.9 counts as stable.

struct Perturbations: Equatable {
    var addNoise = false
    var scaleAmplitude = false
    var shiftTime = false
    var removeChannels = false

    var isEmpty: Bool { !(addNoise || scaleAmplitude || shiftTime || removeChannels) }
}

struct TrustCheckResult {
    let original: TrialPrediction
    let perturbed: TrialPrediction
    /// Spearman ρ between original and perturbed contributions.
    let stability: Double

    var predictionPreserved: Bool { original.predicted == perturbed.predicted }
    var isStable: Bool { stability > TrustCheck.stableThreshold }
}

enum TrustCheck {
    static let noiseFraction: Float = 0.05      // σ of the noise = 5% of each channel's SD
    static let scaleFactor: Float = 1.2
    static let timeShiftSeconds = 0.102
    static let removedChannelNames = ["C3", "Cz", "C4"]
    static let stableThreshold = 0.9

    /// 102 ms at 128 Hz rounds to 13 samples (101.6 ms).
    static func shiftSamples(sampleRate: Double) -> Int {
        Int((timeShiftSeconds * sampleRate).rounded())
    }

    static func evaluate(
        trial: EEGTrial,
        original: TrialPrediction,
        model: LDAModel,
        perturbations: Perturbations,
        sampleRate: Double
    ) -> TrustCheckResult {
        let perturbedTrial = perturb(trial, perturbations, sampleRate: sampleRate)
        let features = LogVarianceFeatures.compute(for: perturbedTrial)

        let removed: Set<Int> = perturbations.removeChannels
            ? Set(removedChannelNames.compactMap { trial.channelNames.firstIndex(of: $0) })
            : []

        let contributions = model.contributions(for: features, removed: removed)
        let perturbed = TrialPrediction(
            probabilityRight: model.probability(fromContributions: contributions),
            contributions: contributions,
            trainedWithoutParticipant: original.trainedWithoutParticipant
        )

        return TrustCheckResult(
            original: original,
            perturbed: perturbed,
            stability: spearman(original.contributions, contributions)
        )
    }

    /// Applies the signal-level perturbations in order: time shift → scale → noise.
    /// (Channel removal happens at the feature level in `evaluate`.)
    static func perturb(_ trial: EEGTrial, _ p: Perturbations, sampleRate: Double) -> EEGTrial {
        var samples = trial.samples

        if p.shiftTime {
            // The export only covers 0–4 s after the cue, so the window is moved 102 ms
            // later by dropping the first samples (no data exists past 4 s to pad with).
            let shift = shiftSamples(sampleRate: sampleRate)
            samples = samples.map { Array($0.dropFirst(min(shift, max($0.count - 2, 0)))) }
        }

        if p.scaleAmplitude {
            samples = samples.map { $0.map { $0 * scaleFactor } }
        }

        if p.addNoise {
            // Seeded by trial id so the same trial always gets the same noise.
            var rng = SeededGenerator(seed: UInt64(trial.id) &* 0x9E37_79B9 &+ 1)
            samples = samples.map { channel in
                let sigma = standardDeviation(channel) * noiseFraction
                return channel.map { $0 + sigma * Float(rng.nextGaussian()) }
            }
        }

        return EEGTrial(
            id: trial.id,
            label: trial.label,
            participant: trial.participant,
            session: trial.session,
            channelNames: trial.channelNames,
            samples: samples
        )
    }

    // MARK: Statistics

    /// Spearman rank correlation (ties get their average rank).
    static func spearman(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, a.count > 1 else { return 1 }
        return pearson(ranks(a), ranks(b))
    }

    static func ranks(_ values: [Double]) -> [Double] {
        let order = values.indices.sorted { values[$0] < values[$1] }
        var result = Array(repeating: 0.0, count: values.count)
        var i = 0
        while i < order.count {
            var j = i
            while j + 1 < order.count && values[order[j + 1]] == values[order[i]] { j += 1 }
            let averageRank = Double(i + j) / 2 + 1
            for k in i...j { result[order[k]] = averageRank }
            i = j + 1
        }
        return result
    }

    static func pearson(_ x: [Double], _ y: [Double]) -> Double {
        let n = Double(x.count)
        let mx = x.reduce(0, +) / n
        let my = y.reduce(0, +) / n
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for (a, b) in zip(x, y) {
            sxy += (a - mx) * (b - my)
            sxx += (a - mx) * (a - mx)
            syy += (b - my) * (b - my)
        }
        guard sxx > 0, syy > 0 else { return sxx == syy ? 1 : 0 }
        return sxy / (sxx * syy).squareRoot()
    }

    private static func standardDeviation(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        let n = Float(values.count)
        let mean = values.reduce(0, +) / n
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / n
        return variance.squareRoot()
    }
}

/// SplitMix64, so noise is reproducible.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Standard normal sample (Box–Muller).
    mutating func nextGaussian() -> Double {
        let u1 = Double.random(in: Double.ulpOfOne..<1, using: &self)
        let u2 = Double.random(in: 0..<1, using: &self)
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}

// MARK: - Panel

struct TrustCheckPanel: View {
    let trial: EEGTrial
    let prediction: TrialPrediction
    let model: LDAModel?
    let sampleRate: Double
    @Binding var perturbations: Perturbations

    var body: some View {
        Card {
            Label("Trust Check", systemImage: "checkmark.shield")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Change the signal and see if the decoder still gives the same answer for the same reasons.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)

            VStack(spacing: 4) {
                toggleRow("Add noise", detail: "Gaussian, 5% of each channel's SD",
                          isOn: $perturbations.addNoise)
                toggleRow("Scale amplitude", detail: "Multiply the signal by 1.2×",
                          isOn: $perturbations.scaleAmplitude)
                toggleRow("Shift time", detail: "Move the window 102 ms later",
                          isOn: $perturbations.shiftTime)
                toggleRow("Remove channels", detail: "Drop C3, Cz and C4",
                          isOn: $perturbations.removeChannels)
            }

            Divider().overlay(Theme.surfaceRaised)

            if perturbations.isEmpty {
                Text("Turn on one or more tests to check this trial.")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
            } else if let model {
                results(TrustCheck.evaluate(
                    trial: trial,
                    original: prediction,
                    model: model,
                    perturbations: perturbations,
                    sampleRate: sampleRate
                ))
            }
        }
    }

    private func toggleRow(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .tint(Theme.teal)
        .frame(minHeight: 56)
    }

    @ViewBuilder
    private func results(_ result: TrustCheckResult) -> some View {
        // 1. Prediction preserved
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Prediction preserved")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("Now: \(result.perturbed.predicted.displayName) hand, \(percent(result.perturbed.confidence))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            badge(result.predictionPreserved ? "Yes" : "No",
                  icon: result.predictionPreserved ? "checkmark" : "xmark",
                  color: result.predictionPreserved ? Theme.green : Theme.amber)
        }
        .accessibilityElement(children: .combine)

        // 2. Explanation stability
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Explanation stability")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("Rank correlation ρ = \(result.stability.formatted(.number.precision(.fractionLength(2))))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            badge(result.isStable ? "Stable" : "Unstable",
                  icon: result.isStable ? "checkmark.seal" : "exclamationmark.triangle",
                  color: result.isStable ? Theme.green : Theme.amber)
        }
        .accessibilityElement(children: .combine)

        Text("Perturbed contributions")
            .font(.headline)
            .foregroundStyle(Theme.textPrimary)
            .padding(.top, 4)
        HeadMapView(channelNames: trial.channelNames, contributions: result.perturbed.contributions)
            .frame(maxWidth: 300)
            .frame(maxWidth: .infinity)

        if perturbations.removeChannels {
            Text("Removed channels are set to their training average, so they contribute 0.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func badge(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.headline)
            .foregroundStyle(Theme.navy)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color, in: Capsule())
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}
