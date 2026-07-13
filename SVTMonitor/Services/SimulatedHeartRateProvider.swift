import Foundation
import Combine

/// A small, self-contained pseudo-random generator so demo behaviour is
/// organic but reproducible run-to-run (xorshift64*).
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }
}

/// Generates a lifelike heart-rate stream for demo mode (and the simulator,
/// where no Apple Watch data exists).
///
/// Baseline is a gentle sinus rhythm around ~72 BPM with slow drift and light
/// noise. `triggerEpisode()` produces a textbook SVT shape: an abrupt ramp to
/// 165–195 BPM over ~10s, a sustained plateau with jitter for 30–90s, then a
/// sudden drop back to baseline.
final class SimulatedHeartRateProvider: HeartRateProvider {

    let source: HeartRateSample.Source = .simulated

    private let subject = PassthroughSubject<HeartRateSample, Never>()
    var samples: AnyPublisher<HeartRateSample, Never> { subject.eraseToAnyPublisher() }

    /// Emitted so the UI can reflect that an episode is being simulated.
    private(set) var isSimulatingEpisode = false

    // Tunables (seconds).
    private let tickInterval: TimeInterval = 2.0
    private let rampDurationTicks = 5          // ~10s

    private enum Phase { case baseline, ramping, sustained, dropping }
    private var phase: Phase = .baseline

    private var timer: Timer?
    private var rng = SeededGenerator(seed: 0xC0FFEE)

    private var drift: Double = 0
    private var lastBPM: Double = 72
    private var rampStartBPM: Double = 72
    private var target: Double = 180
    private var rampProgressTicks = 0
    private var sustainTicksRemaining = 0

    // MARK: HeartRateProvider

    func startStreaming() {
        stopStreaming()
        phase = .baseline
        // Bootstrap with an immediate reading so the UI isn't blank.
        emit(bpm: currentBaseline())

        let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopStreaming() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: Demo control

    /// Kick off a simulated SVT episode. Ignored if one is already ramping or
    /// sustained.
    func triggerEpisode() {
        guard phase == .baseline else { return }
        rampStartBPM = lastBPM
        target = Double.random(in: 165...195, using: &rng)
        rampProgressTicks = 0
        phase = .ramping
        isSimulatingEpisode = true
    }

    // MARK: Simulation

    private func tick() {
        let bpm: Double
        switch phase {
        case .baseline:
            bpm = currentBaseline()
        case .ramping:
            rampProgressTicks += 1
            let t = min(1.0, Double(rampProgressTicks) / Double(rampDurationTicks))
            // Ease-in for an accelerating, sudden-feeling onset.
            let eased = t * t
            let jitter = Double.random(in: -4...4, using: &rng)
            bpm = rampStartBPM + (target - rampStartBPM) * eased + jitter
            if rampProgressTicks >= rampDurationTicks {
                phase = .sustained
                sustainTicksRemaining = Int.random(in: 15...45, using: &rng) // 30–90s
            }
        case .sustained:
            let jitter = Double.random(in: -9...9, using: &rng)
            bpm = target + jitter
            sustainTicksRemaining -= 1
            if sustainTicksRemaining <= 0 { phase = .dropping }
        case .dropping:
            // Abrupt return to baseline, characteristic of SVT termination.
            phase = .baseline
            isSimulatingEpisode = false
            bpm = currentBaseline()
        }
        emit(bpm: bpm)
    }

    /// Slow-drifting sinus baseline with light beat-to-beat noise.
    private func currentBaseline() -> Double {
        drift += Double.random(in: -0.8...0.8, using: &rng)
        drift = min(8, max(-8, drift))
        let noise = Double.random(in: -2.5...2.5, using: &rng)
        return (72 + drift + noise).clamped(to: 55...92)
    }

    private func emit(bpm: Double) {
        let value = bpm.clamped(to: 40...220)
        lastBPM = value
        subject.send(HeartRateSample(bpm: value, date: Date(), source: .simulated))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
