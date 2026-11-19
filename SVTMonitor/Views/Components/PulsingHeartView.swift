import SwiftUI

/// A small heart glyph that beats at the current heart rate, like the one next
/// to the reading in the Watch Heart Rate app.
///
/// Uses `TimelineView(.animation)` so the pulse phase is derived continuously
/// from the clock and the beat interval (60 / BPM). Changing BPM smoothly
/// speeds up or slows the beat without restarting any animation. When no rate
/// is available it sits still.
struct PulsingHeartView: View {
    let bpm: Int?
    var tint: Color

    var body: some View {
        TimelineView(.animation(paused: bpm == nil)) { timeline in
            let interval = beatInterval
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: interval)) / interval
            let scale = 1.0 + 0.16 * beatEnvelope(phase: phase)

            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(bpm == nil ? Theme.inkSecondary : tint)
                .scaleEffect(bpm == nil ? 1 : scale)
        }
        .accessibilityHidden(true)
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
