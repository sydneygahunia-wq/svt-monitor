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
/// Baseline is a resting sinus rhythm around ~72 bpm with slow drift and
/// light noise. `triggerEpisode()` follows how SVT actually behaves, which is
/// what separates it from exercise or anxiety:
///
/// - **Sudden start.** The rate jumps within a few seconds rather than
///   climbing, so the first reading is already partway there and the next
///   is at the episode rate.
/// - **Fast and very regular.** It holds 160–200 bpm with only a couple of
///   bpm of wobble, unlike the noisier rise of sinus tachycardia.
/// - **Sudden stop.** The rate falls back in one step to a slightly raised
///   sinus rate, then settles toward resting over about half a minute.
///
/// Real episodes last minutes to hours; this one is shortened to 40–70 s so
/// the demo is watchable.
final class SimulatedHeartRateProvider: HeartRateProvider {

    let source: HeartRateSample.Source = .simulated

    private let subject = PassthroughSubject<HeartRateSample, Never>()
    var samples: AnyPublisher<HeartRateSample, Never> { subject.eraseToAnyPublisher() }

    /// Emitted so the UI can reflect that an episode is being simulated.
    private(set) var isSimulatingEpisode = false

    /// Seconds between readings.
    private let tickInterval: TimeInterval = 2.0

    private enum Phase { case baseline, onset, sustained }
    private var phase: Phase = .baseline

    private var timer: Timer?
    private var rng = SeededGenerator(seed: 0xC0FFEE)

    private var drift: Double = 0
    private var lastBPM: Double = 72
    private var target: Double = 180
    private var sustainTicksRemaining = 0
    /// Extra bpm on top of baseline right after an episode ends; decays to 0.
    private var recoveryBoost: Double = 0

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

    /// Start a simulated SVT episode. Ignored if one is already running.
    func triggerEpisode() {
        guard phase == .baseline else { return }
        target = Double.random(in: 165...195, using: &rng).rounded()
        sustainTicksRemaining = Int.random(in: 20...35, using: &rng) // 40–70 s
        phase = .onset
        isSimulatingEpisode = true
    }

    // MARK: Simulation

    private func tick() {
        let bpm: Double
        switch phase {
        case .baseline:
            bpm = currentBaseline()
        case .onset:
            // The watch averages over a few seconds, so the reading taken
            // across the jump lands partway between the two rates.
            bpm = lastBPM + (target - lastBPM) * 0.65
            phase = .sustained
        case .sustained:
            bpm = target + Double.random(in: -2...2, using: &rng)
            sustainTicksRemaining -= 1
            if sustainTicksRemaining <= 0 {
                phase = .baseline
                isSimulatingEpisode = false
                recoveryBoost = 22
            }
        }
        emit(bpm: bpm)
    }

    /// Slow-drifting sinus baseline with light noise, plus any post-episode
    /// boost that fades over roughly 30 s.
    private func currentBaseline() -> Double {
        drift += Double.random(in: -0.8...0.8, using: &rng)
        drift = min(8, max(-8, drift))
        let noise = Double.random(in: -2.5...2.5, using: &rng)
        let value = (72 + drift + noise).clamped(to: 55...92) + recoveryBoost
        recoveryBoost *= 0.87
        if recoveryBoost < 0.5 { recoveryBoost = 0 }
        return value
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
