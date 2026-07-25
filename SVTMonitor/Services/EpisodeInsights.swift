import Foundation

/// Pure analysis over a set of episodes.
///
/// Kept free of SwiftUI and SwiftData so it can be unit-tested directly against
/// plain arrays. Everything here is descriptive counting — the app never tries
/// to infer causation from a trigger tag, because "you drank coffee before
/// three episodes" is a prompt for a conversation with a cardiologist, not a
/// conclusion.
enum EpisodeInsights {

    /// A tag and how often it appeared.
    struct TagCount<Tag: Hashable>: Identifiable, Equatable {
        let tag: Tag
        let count: Int
        /// Share of episodes carrying this tag, 0–1.
        let share: Double

        var id: String { String(describing: tag) }
        var percentText: String { "\(Int((share * 100).rounded()))%" }
    }

    /// Everything the Trends screen needs, computed in one pass.
    struct Summary: Equatable {
        let episodeCount: Int
        let taggedCount: Int
        let averageDuration: TimeInterval
        let longestDuration: TimeInterval
        let averagePeakBPM: Double
        let highestPeakBPM: Double
        let averageSeverity: Double?
        let topSymptoms: [TagCount<Symptom>]
        let topTriggers: [TagCount<EpisodeTrigger>]

        static let empty = Summary(
            episodeCount: 0,
            taggedCount: 0,
            averageDuration: 0,
            longestDuration: 0,
            averagePeakBPM: 0,
            highestPeakBPM: 0,
            averageSeverity: nil,
            topSymptoms: [],
            topTriggers: []
        )
    }

    /// Build a summary for the given episodes. Order-independent.
    static func summarize(_ episodes: [SVTEpisode]) -> Summary {
        guard !episodes.isEmpty else { return .empty }

        let durations = episodes.map(\.duration)
        let peaks = episodes.map(\.peakBPM)
        let severities = episodes.map(\.perceivedSeverity).filter { $0 > 0 }

        let symptomTagged = episodes.filter { !$0.symptoms.isEmpty }
        let triggerTagged = episodes.filter { !$0.triggers.isEmpty }
        let taggedCount = episodes.filter { !$0.symptoms.isEmpty || !$0.triggers.isEmpty }.count

        return Summary(
            episodeCount: episodes.count,
            taggedCount: taggedCount,
            averageDuration: durations.reduce(0, +) / Double(durations.count),
            longestDuration: durations.max() ?? 0,
            averagePeakBPM: peaks.reduce(0, +) / Double(peaks.count),
            highestPeakBPM: peaks.max() ?? 0,
            averageSeverity: severities.isEmpty
                ? nil
                : Double(severities.reduce(0, +)) / Double(severities.count),
            topSymptoms: rank(
                episodes.flatMap { Array(Set($0.symptoms)) },
                outOf: symptomTagged.count
            ),
            topTriggers: rank(
                episodes.flatMap { Array(Set($0.triggers)) },
                outOf: triggerTagged.count
            )
        )
    }

    /// Count occurrences and sort by frequency, then alphabetically so the
    /// order is stable when counts tie.
    static func rank<Tag: Hashable & RawRepresentable>(
        _ tags: [Tag],
        outOf denominator: Int
    ) -> [TagCount<Tag>] where Tag.RawValue == String {
        guard !tags.isEmpty else { return [] }

        var counts: [Tag: Int] = [:]
        for tag in tags { counts[tag, default: 0] += 1 }

        let base = max(denominator, 1)
        return counts
            .map { TagCount(tag: $0.key, count: $0.value, share: Double($0.value) / Double(base)) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.tag.rawValue < $1.tag.rawValue
            }
    }

    /// Episodes grouped into calendar weeks, oldest first.
    static func perWeek(_ episodes: [SVTEpisode], calendar: Calendar = .current) -> [(weekStart: Date, count: Int)] {
        var buckets: [Date: Int] = [:]
        for episode in episodes {
            let start = calendar.dateInterval(of: .weekOfYear, for: episode.startDate)?.start
                ?? episode.startDate
            buckets[start, default: 0] += 1
        }
        return buckets
            .map { (weekStart: $0.key, count: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    /// A plain-text summary intended to be read out or handed over at an
    /// appointment. Deliberately factual — counts and ranges, no interpretation.
    static func appointmentSummary(
        for episodes: [SVTEpisode],
        rangeDescription: String,
        generatedAt: Date = Date()
    ) -> String {
        let summary = summarize(episodes)

        let dateStyle = DateFormatter()
        dateStyle.dateStyle = .medium
        dateStyle.timeStyle = .short

        var lines: [String] = []
        lines.append("SVT Monitor — episode summary")
        lines.append("Range: \(rangeDescription)")
        lines.append("Generated: \(dateStyle.string(from: generatedAt))")
        lines.append("")

        guard summary.episodeCount > 0 else {
            lines.append("No episodes recorded in this range.")
            return lines.joined(separator: "\n")
        }

        lines.append("Episodes recorded: \(summary.episodeCount)")
        lines.append("Average duration: \(SVTEpisode.format(duration: summary.averageDuration))")
        lines.append("Longest: \(SVTEpisode.format(duration: summary.longestDuration))")
        lines.append("Average peak: \(Int(summary.averagePeakBPM.rounded())) BPM")
        lines.append("Highest peak: \(Int(summary.highestPeakBPM.rounded())) BPM")
        if let severity = summary.averageSeverity {
            lines.append("Average self-rated severity: \(String(format: "%.1f", severity)) of 5")
        }

        if !summary.topSymptoms.isEmpty {
            lines.append("")
            lines.append("Most reported symptoms:")
            for entry in summary.topSymptoms.prefix(5) {
                lines.append("  • \(entry.tag.title) — \(entry.count) episode(s)")
            }
        }

        if !summary.topTriggers.isEmpty {
            lines.append("")
            lines.append("Most reported possible triggers:")
            for entry in summary.topTriggers.prefix(5) {
                lines.append("  • \(entry.tag.title) — \(entry.count) episode(s)")
            }
        }

        lines.append("")
        lines.append("Episode log:")
        for episode in episodes.sorted(by: { $0.startDate > $1.startDate }) {
            var parts = ["  • \(dateStyle.string(from: episode.startDate))"]
            parts.append("\(episode.durationText), peak \(Int(episode.peakBPM.rounded())) BPM")
            if !episode.symptoms.isEmpty {
                parts.append("symptoms: " + episode.symptoms.map(\.title).joined(separator: ", "))
            }
            if !episode.triggers.isEmpty {
                parts.append("possible triggers: " + episode.triggers.map(\.title).joined(separator: ", "))
            }
            if episode.isManualEntry { parts.append("logged manually") }
            lines.append(parts.joined(separator: " — "))
        }

        lines.append("")
        lines.append("Recorded with SVT Monitor, a personal tracking app. Not a medical device.")
        return lines.joined(separator: "\n")
    }
}
