import Foundation

/// Pure, unit-testable threshold state machine that turns a stream of
/// `HeartRateSample`s into discrete SVT episodes.
///
/// It supports two independent ways to enter an episode, both characteristic
/// of SVT:
///   1. **Sustained tachycardia** — `enterConsecutive` samples at/above the
///      configured `threshold`.
///   2. **Sudden onset** — a rise of `onsetDelta` BPM within `onsetWindow`
///      seconds, once the rate is elevated. SVT famously starts abruptly, so
///      this catches an episode a little earlier than the sustained rule.
///
/// Exit uses hysteresis: the episode only ends after `exitConsecutive`
/// consecutive samples fall below `threshold − exitMargin`, so a brief dip
/// mid-episode doesn't prematurely close it.
///
/// The detector is deliberately free of SwiftData / notifications so it can be
/// tested in isolation; callers react to the emitted `Event`s.
final class EpisodeDetector {

    // MARK: Configuration

    struct Config: Equatable {
        /// BPM at/above which a sample counts as "high".
        var threshold: Double = 150
        /// Sudden-onset rise (BPM) within `onsetWindow` that triggers an episode.
        var onsetDelta: Double = 40
        /// Look-back window for the onset rule.
        var onsetWindow: TimeInterval = 60
        /// Consecutive high samples required to enter an episode.
        var enterConsecutive: Int = 3
        /// Consecutive low samples required to exit an episode.
        var exitConsecutive: Int = 4
        /// Hysteresis band below `threshold` that keeps an episode alive.
        var exitMargin: Double = 10
        /// The rate must be at least `threshold − onsetFloorMargin` for the
        /// onset rule to fire, so a jump from a very low rate to a still-normal
        /// rate doesn't trigger.
        var onsetFloorMargin: Double = 20

        var exitThreshold: Double { threshold - exitMargin }
        var onsetFloor: Double { threshold - onsetFloorMargin }
    }

    // MARK: Output types

    /// Snapshot of an in-progress episode, emitted with `started` / `updated`.
    struct ActiveSummary: Equatable {
        let startDate: Date
        let peakBPM: Double
        let avgBPM: Double
        let sampleCount: Int
        let currentBPM: Double
    }

    /// A completed episode ready to be persisted.
    struct DetectedEpisode: Equatable {
        let startDate: Date
        let endDate: Date
        let peakBPM: Double
        let avgBPM: Double
        let sampleCount: Int
        let hrTrace: [Double]

        var duration: TimeInterval { endDate.timeIntervalSince(startDate) }
    }

    enum Event: Equatable {
        case started(ActiveSummary)
        case updated(ActiveSummary)
        case ended(DetectedEpisode)
    }

    // MARK: State

    private enum State { case normal, episode }

    private struct ActiveEpisode {
        let startDate: Date
        var peak: Double = 0
        var sum: Double = 0
        var count: Int = 0
        var trace: [Double] = []

        mutating func add(_ bpm: Double) {
            peak = max(peak, bpm)
            sum += bpm
            count += 1
            trace.append(bpm)
        }

        var avg: Double { count > 0 ? sum / Double(count) : 0 }
    }

    private(set) var config: Config

    private var state: State = .normal
    private var active: ActiveEpisode?
    private var pendingHigh: [HeartRateSample] = []
    private var pendingLow: [HeartRateSample] = []
    private var window: [(date: Date, bpm: Double)] = []
    private var lastProcessedDate: Date = .distantPast

    // MARK: Init

    init(config: Config = Config()) {
        self.config = config
    }

    /// Update tuning at runtime. Does not disturb an in-progress episode's
    /// accumulated stats, only future decisions.
    func updateConfig(_ newConfig: Config) {
        config = newConfig
    }

    /// True while an episode is currently in progress.
    var isInEpisode: Bool { state == .episode }

    /// Current in-progress episode snapshot, if any.
    var activeSummary: ActiveSummary? {
        guard let active else { return nil }
        return ActiveSummary(
            startDate: active.startDate,
            peakBPM: active.peak,
            avgBPM: active.avg,
            sampleCount: active.count,
            currentBPM: window.last?.bpm ?? active.peak
        )
    }

    // MARK: Processing

    /// Feed a single sample. Returns an event if this sample caused a
    /// transition or update, otherwise `nil`.
    ///
    /// Robust to duplicate and out-of-order samples: anything with a timestamp
    /// at or before the last processed sample is ignored, as are non-positive
    /// BPM readings.
    @discardableResult
    func process(_ sample: HeartRateSample) -> Event? {
        guard sample.bpm > 0 else { return nil }
        guard sample.date > lastProcessedDate else { return nil }

        trimWindow(now: sample.date)
        let previousBPM = window.last?.bpm
        // Calm baseline: nothing in the look-back window was already elevated.
        // Without this, a dip-and-recover between highs reads as an "onset".
        let baselineCalm = window.allSatisfy { $0.bpm < config.onsetFloor }

        window.append((sample.date, sample.bpm))
        lastProcessedDate = sample.date

        switch state {
        case .normal:
            return handleNormal(sample, previousBPM: previousBPM, baselineCalm: baselineCalm)
        case .episode:
            return handleEpisode(sample)
        }
    }

    /// Force-close any in-progress episode (e.g. the user stopped monitoring).
    /// Returns the finalized episode if one was active.
    @discardableResult
    func forceEnd(at date: Date) -> DetectedEpisode? {
        guard state == .episode, let active else { return nil }
        // Fold any tentative low samples into the trace so the come-down shows.
        var episode = active
        for s in pendingLow { episode.add(s.bpm) }
        let end = max(date, active.startDate)
        let finished = finalize(episode, endDate: end)
        resetToNormal()
        return finished
    }

    /// Reset all state to idle. Used when tearing down monitoring.
    func reset() {
        resetToNormal()
        window.removeAll()
        lastProcessedDate = .distantPast
    }

    // MARK: - Normal state

    private func handleNormal(_ sample: HeartRateSample, previousBPM: Double?, baselineCalm: Bool) -> Event? {
        // Sudden-onset rule takes precedence: an abrupt jump measured against
        // the immediately preceding sample, from a calm baseline — so neither
        // a gradual climb nor a dip-and-recover between highs can fire it.
        if let previousBPM,
           baselineCalm,
           sample.bpm - previousBPM >= config.onsetDelta,
           sample.bpm >= config.onsetFloor {
            return startEpisode(seed: [sample], startDate: sample.date)
        }

        // Sustained-tachycardia rule.
        if sample.bpm >= config.threshold {
            pendingHigh.append(sample)
            if pendingHigh.count >= config.enterConsecutive {
                let seed = pendingHigh
                let start = seed.first?.date ?? sample.date
                pendingHigh.removeAll()
                return startEpisode(seed: seed, startDate: start)
            }
            return nil
        } else {
            pendingHigh.removeAll()
            return nil
        }
    }

    private func startEpisode(seed: [HeartRateSample], startDate: Date) -> Event {
        var episode = ActiveEpisode(startDate: startDate)
        for s in seed { episode.add(s.bpm) }
        active = episode
        state = .episode
        pendingLow.removeAll()
        pendingHigh.removeAll()
        return .started(summary(current: seed.last?.bpm ?? episode.peak))
    }

    // MARK: - Episode state

    private func handleEpisode(_ sample: HeartRateSample) -> Event? {
        guard var episode = active else { resetToNormal(); return nil }

        if sample.bpm >= config.exitThreshold {
            // Still elevated: any tentative dip was just noise — fold it back in.
            for s in pendingLow { episode.add(s.bpm) }
            pendingLow.removeAll()
            episode.add(sample.bpm)
            active = episode
            return .updated(summary(current: sample.bpm))
        } else {
            pendingLow.append(sample)
            if pendingLow.count >= config.exitConsecutive {
                // Episode ends at the moment the rate first dropped.
                let endDate = pendingLow.first?.date ?? sample.date
                let finished = finalize(episode, endDate: endDate)
                resetToNormal()
                return .ended(finished)
            }
            active = episode
            return .updated(summary(current: sample.bpm))
        }
    }

    // MARK: - Helpers

    private func finalize(_ episode: ActiveEpisode, endDate: Date) -> DetectedEpisode {
        DetectedEpisode(
            startDate: episode.startDate,
            endDate: endDate,
            peakBPM: episode.peak,
            avgBPM: episode.avg,
            sampleCount: episode.count,
            hrTrace: Self.downsample(episode.trace, maxPoints: 120)
        )
    }

    private func summary(current: Double) -> ActiveSummary {
        let episode = active ?? ActiveEpisode(startDate: lastProcessedDate)
        return ActiveSummary(
            startDate: episode.startDate,
            peakBPM: episode.peak,
            avgBPM: episode.avg,
            sampleCount: episode.count,
            currentBPM: current
        )
    }

    private func resetToNormal() {
        state = .normal
        active = nil
        pendingHigh.removeAll()
        pendingLow.removeAll()
    }

    private func trimWindow(now: Date) {
        let cutoff = now.addingTimeInterval(-config.onsetWindow)
        window.removeAll { $0.date < cutoff }
    }

    /// Reduce a trace to at most `maxPoints` by averaging even-sized buckets,
    /// preserving overall shape.
    static func downsample(_ values: [Double], maxPoints: Int) -> [Double] {
        guard maxPoints > 0 else { return [] }
        guard values.count > maxPoints else { return values }
        let bucketSize = Double(values.count) / Double(maxPoints)
        var result: [Double] = []
        result.reserveCapacity(maxPoints)
        for i in 0..<maxPoints {
            let start = Int((Double(i) * bucketSize).rounded(.down))
            let end = Int((Double(i + 1) * bucketSize).rounded(.down))
            let clampedEnd = min(max(end, start + 1), values.count)
            let slice = values[start..<clampedEnd]
            if slice.isEmpty { continue }
            result.append(slice.reduce(0, +) / Double(slice.count))
        }
        return result
    }
}
