import Foundation
import SwiftData

/// A recorded (or in-progress) possible SVT episode.
///
/// Persisted with SwiftData so episodes survive relaunches and can be queried
/// directly in views via `@Query`.
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

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        peakBPM: Double,
        avgBPM: Double,
        sampleCount: Int,
        hrTrace: [Double] = [],
        notes: String = ""
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.peakBPM = peakBPM
        self.avgBPM = avgBPM
        self.sampleCount = sampleCount
        self.hrTrace = hrTrace
        self.notes = notes
    }

    /// True while the episode has not yet ended.
    var isOngoing: Bool { endDate == nil }

    /// Episode length. For an ongoing episode this measures up to "now".
    var duration: TimeInterval {
        (endDate ?? Date()).timeIntervalSince(startDate)
    }

    /// e.g. "2m 14s".
    var durationText: String { SVTEpisode.format(duration: duration) }

    static func format(duration: TimeInterval) -> String {
        let total = Int(duration.rounded())
        let minutes = total / 60
        let seconds = total % 60
        if minutes == 0 { return "\(seconds)s" }
        return "\(minutes)m \(seconds)s"
    }
}
