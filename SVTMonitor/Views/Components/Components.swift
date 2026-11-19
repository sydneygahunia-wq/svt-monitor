import SwiftUI
import UIKit

/// A dot and a word, the way the Watch shows workout state. No capsule: the
/// color and the wording carry it.
struct StatusPill: View {
    let status: MonitorStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.tint)
                .frame(width: 7, height: 7)
            Text(status.label)
                .font(Theme.font(15, .semibold))
                .foregroundStyle(status.tint)
        }
        .animation(.easeInOut(duration: 0.3), value: status)
    }
}

/// Small labelled metric used in headlines and rows.
struct MetricView: View {
    let value: String
    let label: String
    var tint: Color = Theme.ink
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(label)
                .font(Theme.font(13))
                .foregroundStyle(Theme.inkSecondary)
            Text(value)
                .font(Theme.number(22))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
    }
}

/// Peak rate in an episode row: the number large, the unit small, like Health.
struct PeakChip: View {
    let peakBPM: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("\(peakBPM)")
                .font(Theme.number(20))
                .foregroundStyle(Theme.ink)
            Text("bpm")
                .font(Theme.font(13, .medium))
                .foregroundStyle(Theme.inkSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Peak \(peakBPM) beats per minute")
    }
}

/// Full-width primary action button in the brand blue.
struct PrimaryButtonLabel: View {
    let title: String
    let systemImage: String
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(Theme.font(17, .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(tint)
        )
    }
}

/// Reusable section header for grouped content.
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(Theme.font(17, .semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Wraps `UIActivityViewController` so a plain-text summary can be shared,
/// printed, or saved. Used to hand an episode history to a clinician.
struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
