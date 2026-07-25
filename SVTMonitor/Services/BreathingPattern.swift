import Foundation

/// A paced-breathing pattern, expressed as a repeating sequence of phases.
///
/// This type is deliberately pure: it holds no timers, no animation and no UI.
/// Given "how many seconds have elapsed since the exercise started" it returns
/// which phase you should be in and how far through it you are. That makes the
/// pacing logic unit-testable without running the app, which matters — a
/// breathing guide that drifts or skips a phase is worse than no guide at all
/// when someone is already panicking.
struct BreathingPattern: Identifiable, Equatable {

    /// One stage of a breath.
    enum Phase: String, Equatable {
        case inhale
        case holdIn
        case exhale
        case holdOut

        var instruction: String {
            switch self {
            case .inhale:  return "Breathe in"
            case .holdIn:  return "Hold"
            case .exhale:  return "Breathe out"
            case .holdOut: return "Hold"
            }
        }

        /// How large the guide circle should be during this phase, 0–1.
        /// Inhale grows, exhale shrinks, holds sit still at either end.
        var startScale: Double {
            switch self {
            case .inhale:  return 0
            case .holdIn:  return 1
            case .exhale:  return 1
            case .holdOut: return 0
            }
        }

        var endScale: Double {
            switch self {
            case .inhale:  return 1
            case .holdIn:  return 1
            case .exhale:  return 0
            case .holdOut: return 0
            }
        }
    }

    /// A phase paired with how long it lasts.
    struct Step: Equatable {
        let phase: Phase
        let duration: TimeInterval
    }

    /// Where the exercise is at a given moment.
    struct State: Equatable {
        let step: Step
        /// 0–1 through the current step.
        let progress: Double
        /// Whole seconds remaining in this step, rounded up (for the countdown).
        let secondsRemaining: Int
        /// How many complete cycles have finished.
        let completedCycles: Int

        /// Interpolated 0–1 guide-circle scale.
        var scale: Double {
            let from = step.phase.startScale
            let to = step.phase.endScale
            return from + (to - from) * progress
        }
    }

    let id: String
    let name: String
    let subtitle: String
    let steps: [Step]

    /// Length of one full cycle through every step.
    var cycleDuration: TimeInterval { steps.reduce(0) { $0 + $1.duration } }

    /// Compact label such as "4-7-8".
    var rhythmText: String {
        steps
            .filter { $0.duration > 0 }
            .map { String(Int($0.duration.rounded())) }
            .joined(separator: "-")
    }

    /// The state of the exercise `elapsed` seconds after it started.
    ///
    /// Returns `nil` only if the pattern has no steps with a positive duration,
    /// which the built-in presets never do.
    func state(at elapsed: TimeInterval) -> State? {
        let active = steps.filter { $0.duration > 0 }
        guard !active.isEmpty else { return nil }

        let cycle = active.reduce(0) { $0 + $1.duration }
        // Clamp negative input to zero rather than trusting the caller's clock.
        let safeElapsed = max(0, elapsed)
        let completedCycles = Int(safeElapsed / cycle)
        var offset = safeElapsed.truncatingRemainder(dividingBy: cycle)

        for step in active {
            if offset < step.duration {
                let progress = step.duration > 0 ? offset / step.duration : 1
                let remaining = Int((step.duration - offset).rounded(.up))
                return State(
                    step: step,
                    progress: min(max(progress, 0), 1),
                    secondsRemaining: max(remaining, 1),
                    completedCycles: completedCycles
                )
            }
            offset -= step.duration
        }

        // Floating-point edge: land on the final step rather than falling through.
        let last = active[active.count - 1]
        return State(
            step: last,
            progress: 1,
            secondsRemaining: 1,
            completedCycles: completedCycles
        )
    }

    // MARK: - Presets

    /// Equal-count breathing. Easiest to follow when your heart is racing and
    /// counting anything feels hard.
    static let box = BreathingPattern(
        id: "box",
        name: "Box breathing",
        subtitle: "Even counts. Easiest to follow first.",
        steps: [
            Step(phase: .inhale,  duration: 4),
            Step(phase: .holdIn,  duration: 4),
            Step(phase: .exhale,  duration: 4),
            Step(phase: .holdOut, duration: 4)
        ]
    )

    /// Long exhale relative to the inhale.
    static let extendedExhale = BreathingPattern(
        id: "extended-exhale",
        name: "Longer exhale",
        subtitle: "Breathe out for longer than you breathe in.",
        steps: [
            Step(phase: .inhale, duration: 4),
            Step(phase: .exhale, duration: 6)
        ]
    )

    /// The familiar 4-7-8 pattern.
    static let fourSevenEight = BreathingPattern(
        id: "4-7-8",
        name: "4-7-8",
        subtitle: "A slower pattern for once things settle.",
        steps: [
            Step(phase: .inhale, duration: 4),
            Step(phase: .holdIn, duration: 7),
            Step(phase: .exhale, duration: 8)
        ]
    )

    static let all: [BreathingPattern] = [.box, .extendedExhale, .fourSevenEight]
}
