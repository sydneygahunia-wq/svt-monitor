import Foundation
import SwiftData

/// A recorded (or in-progress) possible SVT episode.
///
/// Persisted with SwiftData so episodes survive relaunches and can be queried
/// directly in views via `@Query`.
///
/// An episode can arrive two ways: detected automatically from a heart-rate
/// stream, or logged by hand after the fact (`isManualEntry`). Both are first
/// class — plenty of episodes happen when you aren't wearing a watch, and an
/// episode you only remember afterwards is still worth recording.
@Model
final class SVTEpisode {

    /// Stable identifier.
    @Attribute(.unique) var id: UUID

    /// When the episode began (first sample at/above threshold or onset trigger).
    var startDate: Date

    /// When the episode ended. `nil` while the episode is still ongoing.
    var endDate: Date?

    /// Highest BPM observed during the episode.
    var peakBPM: Double

    /// Mean BPM across all in-episode samples.
    var avgBPM: Double

    /// How many heart-rate samples contributed to the episode.
    var sampleCount: Int

    /// Down-sampled BPM trace for charting (≤ 120 points).
    var hrTrace: [Double]

    /// Patient notes, editable in the detail view.
    var notes: String

    /// Symptoms tagged by the user, stored as `Symptom` raw values.
    var symptomsRaw: [String] = []

    /// Possible triggers tagged by the user, stored as `EpisodeTrigger` raw values.
    var triggersRaw: [String] = []

    /// How rough it felt, 1–5. `0` means the user hasn't rated it.
    var perceivedSeverity: Int = 0

    /// True when the user typed this episode in rather than it being detected.
    var isManualEntry: Bool = false

    /// True if the user opened Calm Mode during this episode. Useful context
    /// when reviewing what helped.
    var usedCalmMode: Bool = false

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        peakBPM: Double,
        avgBPM: Double,
        sampleCount: Int,
        hrTrace: [Double] = [],
        notes: String = "",
        symptoms: [Symptom] = [],
        triggers: [EpisodeTrigger] = [],
        perceivedSeverity: Int = 0,
        isManualEntry: Bool = false,
        usedCalmMode: Bool = false
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.peakBPM = peakBPM
        self.avgBPM = avgBPM
        self.sampleCount = sampleCount
        self.hrTrace = hrTrace
        self.notes = notes
        self.symptomsRaw = symptoms.map(\.rawValue)
        self.triggersRaw = triggers.map(\.rawValue)
        self.perceivedSeverity = perceivedSeverity
        self.isManualEntry = isManualEntry
        self.usedCalmMode = usedCalmMode
    }

    // MARK: - Typed tag access
    //
    // SwiftData persists plain `[String]` happily, so the enums are stored as
    // raw values and surfaced as typed arrays here. Unknown raw values (e.g.
    // written by a newer build) are dropped rather than crashing.

    var symptoms: [Symptom] {
        get { symptomsRaw.compactMap(Symptom.init(rawValue:)) }
        set { symptomsRaw = newValue.map(\.rawValue) }
    }

    var triggers: [EpisodeTrigger] {
        get { triggersRaw.compactMap(EpisodeTrigger.init(rawValue:)) }
        set { triggersRaw = newValue.map(\.rawValue) }
    }

    /// True when any tagged symptom is one the app flags for urgent-care advice.
    var hasRedFlagSymptom: Bool { symptoms.contains(where: \.isRedFlag) }

    // MARK: - Derived

    /// True while the episode has not yet ended.
    var isOngoing: Bool { endDate == nil }

    /// Episode length. For an ongoing episode this measures up to "now".
    var duration: TimeInterval {
        (endDate ?? Date()).timeIntervalSince(startDate)
    }

    /// e.g. "2m 14s".
    var durationText: String { SVTEpisode.format(duration: duration) }

    /// Human label for the 1–5 severity rating.
    var severityText: String? { SVTEpisode.severityLabel(perceivedSeverity) }

    static func severityLabel(_ value: Int) -> String? {
        switch value {
        case 1: return "Barely noticed"
        case 2: return "Mild"
        case 3: return "Uncomfortable"
        case 4: return "Rough"
        case 5: return "Frightening"
        default: return nil
        }
    }

    static func format(duration: TimeInterval) -> String {
        let total = Int(duration.rounded())
        let minutes = total / 60
        let seconds = total % 60
        if minutes == 0 { return "\(seconds)s" }
        return "\(minutes)m \(seconds)s"
    }
}
