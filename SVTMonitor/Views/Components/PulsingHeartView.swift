import SwiftUI

/// A soft heart that visibly beats at the current heart rate.
///
/// Uses `TimelineView(.animation)` so the pulse phase is derived continuously
/// from the clock and the beat interval (60 / BPM). Changing BPM smoothly
/// speeds up or slows the beat without restarting any animation. When no rate
/// is available it breathes gently at ~55 BPM.
struct PulsingHeartView: View {
    let bpm: Int?
    var tint: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let interval = beatInterval
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: interval)) / interval
            let envelope = beatEnvelope(phase: phase)
            let coreScale = 1.0 + 0.14 * envelope
            let glowScale = 1.0 + 0.30 * envelope

            ZStack {
                // Soft glow that expands with each beat.
                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(tint.opacity(0.28))
                    .blur(radius: 18)
                    .scaleEffect(glowScale)

                // Crisp heart.
                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(tint)
                    .scaleEffect(coreScale)
                    .shadow(color: tint.opacity(0.35), radius: 10, y: 4)
            }
        }
        .accessibilityLabel("Heart beating at \(bpm.map(String.init) ?? "an unknown") beats per minute")
    }

    private var beatInterval: Double {
        guard let bpm, bpm > 0 else { return 60.0 / 55.0 }
        return 60.0 / Double(min(max(bpm, 30), 220))
    }

    /// A crisp "lub-dub" spike each cycle rather than a slow sine swell.
    private func beatEnvelope(phase: Double) -> Double {
        let lub = exp(-pow((phase - 0.10) / 0.055, 2))
        let dub = 0.55 * exp(-pow((phase - 0.26) / 0.055, 2))
        return min(1.0, max(lub, dub))
    }
}
