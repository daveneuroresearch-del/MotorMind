import Foundation

// A small, explainable motor-imagery decoder:
//   1. Feature per channel = log(variance of the signal)   (band power, 4–40 Hz)
//   2. Features are z-scored with the training set's mean and std
//   3. Two-class linear discriminant analysis (LDA) with Ledoit–Wolf shrinkage
//   4. Evaluated leave-one-participant-out: each participant is tested by a model
//      that never saw any of their trials.
//
// score = Σ wᵢ·zᵢ + b,   P(right) = 1 / (1 + e^(−score))
// The contribution of channel i is wᵢ·zᵢ: positive pushes toward RIGHT, negative toward LEFT.

// MARK: - Features

enum LogVarianceFeatures {
    /// One log-variance value per channel, in the trial's channel order.
    static func compute(for trial: EEGTrial) -> [Double] {
        trial.samples.map { channel in
            guard !channel.isEmpty else { return 0 }
            let n = Double(channel.count)
            var mean = 0.0
            for v in channel { mean += Double(v) }
            mean /= n
            var sumSquares = 0.0
            for v in channel {
                let d = Double(v) - mean
                sumSquares += d * d
            }
            return log(max(sumSquares / n, 1e-12))
        }
    }
}

// MARK: - Model

struct LDAModel: Sendable {
    let featureMean: [Double]
    let featureStd: [Double]
    let weights: [Double]
    let bias: Double
    let shrinkage: Double

    func standardize(_ features: [Double]) -> [Double] {
        zip(features, zip(featureMean, featureStd)).map { x, ms in (x - ms.0) / ms.1 }
    }

    /// wᵢ·zᵢ for each channel. Channels in `removed` are treated as missing:
    /// their z-score is set to 0 (the training average), so they contribute nothing.
    func contributions(for features: [Double], removed: Set<Int> = []) -> [Double] {
        zip(weights, standardize(features)).enumerated().map { item in
            removed.contains(item.offset) ? 0 : item.element.0 * item.element.1
        }
    }

    func probabilityRight(for features: [Double], removed: Set<Int> = []) -> Double {
        probability(fromContributions: contributions(for: features, removed: removed))
    }

    func probability(fromContributions contributions: [Double]) -> Double {
        let score = contributions.reduce(bias, +)
        return 1 / (1 + exp(-score))
    }

    /// Trains on log-variance features. `labels` must contain both classes.
    static func fit(features X: [[Double]], labels: [EEGTrial.Label]) -> LDAModel {
        let n = X.count
        let d = X.first?.count ?? 0

        // z-score using the training set only
        let mean = (0..<d).map { j in X.reduce(0) { $0 + $1[j] } / Double(n) }
        let std = (0..<d).map { j -> Double in
            let v = X.reduce(0) { $0 + pow($1[j] - mean[j], 2) } / Double(n)
            return v > 1e-24 ? sqrt(v) : 1
        }
        let Z = X.map { row in (0..<d).map { (row[$0] - mean[$0]) / std[$0] } }

        let left = zip(Z, labels).filter { $0.1 == .left }.map(\.0)
        let right = zip(Z, labels).filter { $0.1 == .right }.map(\.0)
        let meanLeft = columnMeans(left, d)
        let meanRight = columnMeans(right, d)

        // Within-class centered rows
        let centered = left.map { sub($0, meanLeft) } + right.map { sub($0, meanRight) }

        let lambda = ledoitWolfShrinkage(centered)

        // Pooled covariance, then shrink toward a scaled identity
        var S = outerSum(centered, d).map { $0.map { $0 / Double(max(n - 2, 1)) } }
        let target = (0..<d).reduce(0) { $0 + S[$1][$1] } / Double(d)
        for i in 0..<d {
            for j in 0..<d {
                S[i][j] = (1 - lambda) * S[i][j] + (i == j ? lambda * target : 0)
            }
        }

        let w = solveSymmetricPositiveDefinite(S, sub(meanRight, meanLeft))
        let midpoint = (0..<d).map { (meanLeft[$0] + meanRight[$0]) / 2 }
        let b = -dot(w, midpoint)

        return LDAModel(featureMean: mean, featureStd: std, weights: w, bias: b, shrinkage: lambda)
    }
}

// MARK: - Leave-one-participant-out evaluation

struct TrialPrediction: Sendable {
    let probabilityRight: Double
    let contributions: [Double]
    let trainedWithoutParticipant: Int

    var predicted: EEGTrial.Label { probabilityRight >= 0.5 ? .right : .left }
    var confidence: Double { max(probabilityRight, 1 - probabilityRight) }
}

struct ParticipantScore: Identifiable, Sendable {
    let participant: Int
    let correct: Int
    let total: Int

    var id: Int { participant }
    var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 0 }
}

struct DecoderReport: Sendable {
    let dataset: EEGDataset
    /// Keyed by trial id.
    let predictions: [Int: TrialPrediction]
    /// The fold model for each held-out participant, keyed by that participant.
    let models: [Int: LDAModel]
    let participantScores: [ParticipantScore]

    var correct: Int { participantScores.reduce(0) { $0 + $1.correct } }
    var total: Int { participantScores.reduce(0) { $0 + $1.total } }
    var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 0 }
}

enum BrainLabDecoder {
    /// Loads the bundled trials and runs the full evaluation. Call off the main thread.
    static func run() throws -> DecoderReport {
        leaveOneParticipantOut(try EEGDataset.loadBundled())
    }

    static func leaveOneParticipantOut(_ dataset: EEGDataset) -> DecoderReport {
        var features: [Int: [Double]] = [:]
        for trial in dataset.trials {
            features[trial.id] = LogVarianceFeatures.compute(for: trial)
        }

        var predictions: [Int: TrialPrediction] = [:]
        var models: [Int: LDAModel] = [:]
        var scores: [ParticipantScore] = []

        for participant in Set(dataset.trials.map(\.participant)).sorted() {
            let train = dataset.trials.filter { $0.participant != participant }
            let test = dataset.trials.filter { $0.participant == participant }
            guard !test.isEmpty, Set(train.map(\.label)).count == 2 else { continue }

            let model = LDAModel.fit(
                features: train.map { features[$0.id, default: []] },
                labels: train.map(\.label)
            )
            models[participant] = model

            var correct = 0
            for trial in test {
                let f = features[trial.id, default: []]
                let prediction = TrialPrediction(
                    probabilityRight: model.probabilityRight(for: f),
                    contributions: model.contributions(for: f),
                    trainedWithoutParticipant: participant
                )
                predictions[trial.id] = prediction
                if prediction.predicted == trial.label { correct += 1 }
            }
            scores.append(ParticipantScore(participant: participant, correct: correct, total: test.count))
        }

        return DecoderReport(dataset: dataset, predictions: predictions, models: models, participantScores: scores)
    }
}

// MARK: - Small linear-algebra helpers

private func dot(_ a: [Double], _ b: [Double]) -> Double {
    zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
}

private func sub(_ a: [Double], _ b: [Double]) -> [Double] {
    zip(a, b).map { $0 - $1 }
}

private func columnMeans(_ rows: [[Double]], _ d: Int) -> [Double] {
    guard !rows.isEmpty else { return Array(repeating: 0, count: d) }
    return (0..<d).map { j in rows.reduce(0) { $0 + $1[j] } / Double(rows.count) }
}

/// Σ xᵀx over rows (not divided by n).
private func outerSum(_ rows: [[Double]], _ d: Int) -> [[Double]] {
    var S = Array(repeating: Array(repeating: 0.0, count: d), count: d)
    for x in rows {
        for i in 0..<d {
            for j in 0..<d {
                S[i][j] += x[i] * x[j]
            }
        }
    }
    return S
}

/// Ledoit–Wolf (2004) shrinkage intensity toward a scaled identity, from centered rows.
private func ledoitWolfShrinkage(_ rows: [[Double]]) -> Double {
    let n = rows.count
    guard n > 1, let d = rows.first?.count, d > 0 else { return 1 }
    let S = outerSum(rows, d).map { $0.map { $0 / Double(n) } }
    let mu = (0..<d).reduce(0) { $0 + S[$1][$1] } / Double(d)

    var delta = 0.0
    for i in 0..<d {
        for j in 0..<d {
            let diff = S[i][j] - (i == j ? mu : 0)
            delta += diff * diff
        }
    }
    delta /= Double(d)

    var beta = 0.0
    for x in rows {
        for i in 0..<d {
            for j in 0..<d {
                let diff = x[i] * x[j] - S[i][j]
                beta += diff * diff
            }
        }
    }
    beta /= Double(d) * Double(n) * Double(n)

    guard delta > 0 else { return 1 }
    return min(beta, delta) / delta
}

/// Solves A·x = b for a symmetric positive-definite A (Cholesky).
private func solveSymmetricPositiveDefinite(_ A: [[Double]], _ b: [Double]) -> [Double] {
    let n = b.count
    var L = Array(repeating: Array(repeating: 0.0, count: n), count: n)
    for i in 0..<n {
        for j in 0...i {
            var sum = A[i][j]
            for k in 0..<j { sum -= L[i][k] * L[j][k] }
            if i == j {
                L[i][i] = sqrt(max(sum, 1e-12))
            } else {
                L[i][j] = sum / L[j][j]
            }
        }
    }
    var y = Array(repeating: 0.0, count: n)
    for i in 0..<n {
        var sum = b[i]
        for k in 0..<i { sum -= L[i][k] * y[k] }
        y[i] = sum / L[i][i]
    }
    var x = Array(repeating: 0.0, count: n)
    for i in stride(from: n - 1, through: 0, by: -1) {
        var sum = y[i]
        for k in (i + 1)..<n { sum -= L[k][i] * x[k] }
        x[i] = sum / L[i][i]
    }
    return x
}
