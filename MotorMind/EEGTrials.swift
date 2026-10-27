import Foundation

/// One motor-imagery EEG trial from the bundled BNCI2014-001 export (Resources/trials.json).
struct EEGTrial: Identifiable, Hashable, Sendable {
    enum Label: String, Decodable, CaseIterable, Sendable {
        case left
        case right
    }

    let id: Int
    let label: Label
    let participant: Int
    let session: String
    let channelNames: [String]
    /// Microvolts, indexed `samples[channel][sample]`, in the same order as `channelNames`.
    let samples: [[Float]]

    /// The samples for one channel, e.g. `trial.samples(for: "C3")`.
    func samples(for channel: String) -> [Float]? {
        guard let index = channelNames.firstIndex(of: channel) else { return nil }
        return samples[index]
    }
}

/// The whole bundled file: settings shared by every trial, plus the trials.
struct EEGDataset: Sendable {
    let name: String
    let sampleRate: Double          // Hz
    let band: ClosedRange<Double>   // Hz
    let windowStart: Double         // seconds from trial start (cue is at 2 s)
    let samplesPerTrial: Int
    let units: String
    let channelNames: [String]
    let participants: [Int]
    let trials: [EEGTrial]

    /// Length of one trial in seconds.
    var trialDuration: Double { Double(samplesPerTrial) / sampleRate }

    func trials(labeled label: EEGTrial.Label) -> [EEGTrial] {
        trials.filter { $0.label == label }
    }

    func trials(forParticipant participant: Int) -> [EEGTrial] {
        trials.filter { $0.participant == participant }
    }
}

// MARK: - Loading

enum EEGDatasetError: LocalizedError {
    case fileNotFound(String)
    case badShape(trialID: Int, expected: String, found: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "Couldn't find \(name).json in the app bundle."
        case .badShape(let id, let expected, let found):
            return "Trial \(id) should be \(expected) but is \(found)."
        }
    }
}

extension EEGDataset {
    /// Reads and checks `trials.json` from the app bundle.
    /// Decoding takes a moment (~270k numbers), so call it from a background task:
    ///
    ///     let dataset = try await Task.detached { try EEGDataset.loadBundled() }.value
    static func loadBundled(named name: String = "trials", bundle: Bundle = .main) throws -> EEGDataset {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw EEGDatasetError.fileNotFound(name)
        }
        return try load(from: Data(contentsOf: url))
    }

    static func load(from data: Data) throws -> EEGDataset {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let file = try decoder.decode(TrialsFile.self, from: data)

        let trials = try file.trials.map { raw -> EEGTrial in
            guard raw.data.count == file.channels.count,
                  raw.data.allSatisfy({ $0.count == file.nSamples }) else {
                throw EEGDatasetError.badShape(
                    trialID: raw.id,
                    expected: "\(file.channels.count) × \(file.nSamples)",
                    found: "\(raw.data.count) × \(raw.data.first?.count ?? 0)"
                )
            }
            return EEGTrial(
                id: raw.id,
                label: raw.label,
                participant: raw.subject,
                session: raw.session,
                channelNames: file.channels,
                samples: raw.data
            )
        }

        let low = file.bandHz.first ?? 0
        let high = file.bandHz.last ?? low
        return EEGDataset(
            name: file.dataset,
            sampleRate: file.sfreqHz,
            band: low...max(low, high),
            windowStart: file.tminS,
            samplesPerTrial: file.nSamples,
            units: file.units,
            channelNames: file.channels,
            participants: file.subjects,
            trials: trials
        )
    }
}

// MARK: - JSON layout (matches export_trials.py)

private struct TrialsFile: Decodable {
    let dataset: String
    let subjects: [Int]
    let bandHz: [Double]
    let sfreqHz: Double
    let tminS: Double
    let nSamples: Int
    let units: String
    let channels: [String]
    let trials: [RawTrial]

    struct RawTrial: Decodable {
        let id: Int
        let subject: Int
        let session: String
        let label: EEGTrial.Label
        let data: [[Float]]
    }
}
