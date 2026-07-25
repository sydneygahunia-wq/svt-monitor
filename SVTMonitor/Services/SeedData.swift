import Foundation
import SwiftData

/// Seeds a handful of realistic historical episodes the first time the app runs
/// in demo mode, so the Episodes and Trends screens feel alive immediately.
enum SeedData {

    /// Descriptor for a seeded episode: how long ago it started, how long it
    /// lasted, and its peak BPM.
    private struct Spec {
        let daysAgo: Double
        let duration: TimeInterval
        let peak: Double
        let notes: String
        var symptoms: [Symptom] = []
        var triggers: [EpisodeTrigger] = []
        var severity: Int = 0
        var manual: Bool = false
    }

    private static let specs: [Spec] = [
        Spec(daysAgo: 20.4, duration: 52,  peak: 158,
             notes: "Came on while climbing stairs. Passed quickly.",
             symptoms: [.palpitations, .shortnessOfBreath],
             triggers: [.exercise], severity: 2),
        Spec(daysAgo: 18.1, duration: 134, peak: 182,
             notes: "Sitting at my desk. Tried slow breathing.",
             symptoms: [.palpitations, .anxiety],
             triggers: [.stress, .caffeine], severity: 3),
        Spec(daysAgo: 15.7, duration: 220, peak: 176,
             notes: "",
             symptoms: [.palpitations, .lightheaded],
             triggers: [.unknown], severity: 3),
        Spec(daysAgo: 12.3, duration: 45,  peak: 163,
             notes: "Very brief, right after coffee.",
             symptoms: [.palpitations],
             triggers: [.caffeine], severity: 1),
        Spec(daysAgo: 9.6,  duration: 370, peak: 191,
             notes: "Longer one. Did a maneuver my cardiologist showed me and it stopped.",
             symptoms: [.palpitations, .chestPressure, .anxiety],
             triggers: [.stress, .poorSleep], severity: 4),
        Spec(daysAgo: 6.2,  duration: 88,  peak: 169,
             notes: "",
             symptoms: [.palpitations],
             triggers: [.caffeine, .dehydration], severity: 2),
        Spec(daysAgo: 3.1,  duration: 295, peak: 198,
             notes: "Woke me up. Felt lightheaded.",
             symptoms: [.palpitations, .lightheaded, .anxiety],
             triggers: [.poorSleep], severity: 4),
        Spec(daysAgo: 1.4,  duration: 118, peak: 172,
             notes: "After a light jog on the treadmill.",
             symptoms: [.palpitations, .shortnessOfBreath],
             triggers: [.exercise, .dehydration], severity: 2),
        // One entry logged by hand, with no trace — the common case where an
        // episode happens away from the watch.
        Spec(daysAgo: 8.0,  duration: 150, peak: 0,
             notes: "No watch on. Wrote it down straight after.",
             symptoms: [.palpitations, .nausea],
             triggers: [.stress], severity: 3, manual: true),
    ]

    /// Insert seed episodes if the store is currently empty. Idempotent.
    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<SVTEpisode>())) ?? 0
        guard existing == 0 else { return }

        let now = Date()
        for spec in specs {
            let start = now.addingTimeInterval(-spec.daysAgo * 86_400)
            // A manually logged episode has no heart-rate trace, by definition.
            let trace = spec.manual
                ? []
                : makeTrace(duration: spec.duration, peak: spec.peak, seed: UInt64(spec.duration) &+ UInt64(spec.peak))
            let avg = trace.isEmpty ? spec.peak : trace.reduce(0, +) / Double(trace.count)
            let episode = SVTEpisode(
                startDate: start,
                endDate: start.addingTimeInterval(spec.duration),
                peakBPM: trace.max() ?? spec.peak,
                avgBPM: avg,
                sampleCount: spec.manual ? 0 : max(trace.count, Int(spec.duration / 2)),
                hrTrace: trace,
                notes: spec.notes,
                symptoms: spec.symptoms,
                triggers: spec.triggers,
                perceivedSeverity: spec.severity,
                isManualEntry: spec.manual
            )
            context.insert(episode)
        }
        try? context.save()
    }

    /// Build a lifelike BPM trace: quick onset ramp, jittery plateau near the
    /// peak, then a come-down. Down-sampled to ≤120 points.
    private static func makeTrace(duration: TimeInterval, peak: Double, seed: UInt64) -> [Double] {
        var state = seed == 0 ? 0x1234_5678 : seed
        func rand(_ lo: Double, _ hi: Double) -> Double {
            state ^= state >> 12; state ^= state << 25; state ^= state >> 27
            let u = Double((state &* 0x2545_F491_4F6C_DD1D) >> 11) / Double(1 << 53)
            return lo + u * (hi - lo)
        }

        let sampleEvery: TimeInterval = 2
        let count = max(6, Int(duration / sampleEvery))
        let onset = max(2, count / 8)          // ~first eighth is the ramp
        let recovery = max(2, count / 10)      // last tenth is the come-down
        let plateauStart = onset
        let plateauEnd = max(plateauStart + 1, count - recovery)

        var values: [Double] = []
        values.reserveCapacity(count)
        let base = 84.0
        for i in 0..<count {
            let bpm: Double
            if i < onset {
                let t = Double(i) / Double(max(1, onset))
                bpm = base + (peak - base) * (t * t) + rand(-3, 3)
            } else if i < plateauEnd {
                bpm = peak - rand(0, 12) + rand(-4, 4)
            } else {
                let t = Double(i - plateauEnd) / Double(max(1, count - plateauEnd))
                bpm = peak - (peak - base) * t + rand(-4, 4)
            }
            values.append(max(70, bpm))
        }
        return EpisodeDetector.downsample(values, maxPoints: 120)
    }
}
