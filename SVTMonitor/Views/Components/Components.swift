import SwiftUI

/// Status capsule shown on the dashboard (MONITORING / POSSIBLE EPISODE / …).
struct StatusPill: View {
    let status: MonitorStatus

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(status.tint)
                .frame(width: 8, height: 8)
            Text(status.label)
                .font(Theme.rounded(13, .bold))
                .tracking(0.6)
                .foregroundStyle(status.tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(status.fill))
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
            Text(value)
                .font(Theme.rounded(22, .bold))
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(Theme.rounded(11, .semibold))
                .tracking(0.5)
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
    }
}

/// A compact peak-BPM chip used in episode rows.
struct PeakChip: View {
    let peakBPM: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.heart.fill")
                .font(.system(size: 11, weight: .bold))
            Text("\(peakBPM)")
                .font(Theme.rounded(14, .bold))
            Text("BPM")
                .font(Theme.rounded(10, .semibold))
                .opacity(0.8)
        }
        .foregroundStyle(Theme.peachDeep)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.peach.opacity(0.28)))
    }
}

/// Full-width primary action button in the brand blue.
struct PrimaryButtonLabel: View {
    let title: String
    let systemImage: String
    var tint: Color = Theme.blueDeep

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
            Text(title)
                .font(Theme.rounded(18, .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint)
        )
        .shadow(color: tint.opacity(0.35), radius: 12, y: 6)
    }
}

/// Reusable section header for grouped content.
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(Theme.rounded(12, .bold))
            .tracking(0.8)
            .foregroundStyle(Theme.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
