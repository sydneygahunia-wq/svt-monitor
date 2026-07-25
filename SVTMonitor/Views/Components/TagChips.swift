import SwiftUI

/// A small read-only tag chip (icon + label) used to show symptoms and
/// triggers on episode rows and detail screens.
struct TagChip: View {
    let title: String
    let systemImage: String
    var tint: Color = Theme.blueDeep

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(Theme.rounded(13, .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.14)))
    }
}

/// A tappable chip used when picking symptoms and triggers.
struct SelectableChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    var tint: Color = Theme.blueDeep
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(Theme.rounded(15, .semibold))
            }
            .foregroundStyle(isSelected ? .white : Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(isSelected ? tint : Theme.background)
            )
            .overlay(
                Capsule().stroke(isSelected ? .clear : Theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Lightweight wrapping layout so chips flow onto multiple lines.
///
/// SwiftUI has no built-in flow layout before iOS 16's `Layout` protocol, and
/// this app targets iOS 17, so a small custom `Layout` keeps the chip grids
/// tidy without dragging in a dependency.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: proposal.width ?? x, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// Reusable symptom picker.
struct SymptomPicker: View {
    @Binding var selection: Set<Symptom>

    var body: some View {
        FlowLayout {
            ForEach(Symptom.allCases) { symptom in
                SelectableChip(
                    title: symptom.title,
                    systemImage: symptom.systemImage,
                    isSelected: selection.contains(symptom),
                    tint: Theme.peachDeep
                ) {
                    toggle(symptom)
                }
            }
        }
    }

    private func toggle(_ symptom: Symptom) {
        if selection.contains(symptom) {
            selection.remove(symptom)
        } else {
            selection.insert(symptom)
        }
    }
}

/// Reusable trigger picker.
struct TriggerPicker: View {
    @Binding var selection: Set<EpisodeTrigger>

    var body: some View {
        FlowLayout {
            ForEach(EpisodeTrigger.allCases) { trigger in
                SelectableChip(
                    title: trigger.title,
                    systemImage: trigger.systemImage,
                    isSelected: selection.contains(trigger)
                ) {
                    toggle(trigger)
                }
            }
        }
    }

    private func toggle(_ trigger: EpisodeTrigger) {
        if selection.contains(trigger) {
            selection.remove(trigger)
        } else {
            selection.insert(trigger)
        }
    }
}

/// 1–5 severity selector.
struct SeverityPicker: View {
    @Binding var severity: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        severity = (severity == value) ? 0 : value
                    } label: {
                        Text("\(value)")
                            .font(Theme.rounded(17, .bold))
                            .foregroundStyle(severity >= value && severity > 0 ? .white : Theme.inkSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(severity >= value && severity > 0 ? Theme.peachDeep : Theme.background)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Theme.hairline, lineWidth: severity >= value && severity > 0 ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(SVTEpisode.severityLabel(severity) ?? "Tap to rate how it felt")
                .font(Theme.rounded(14))
                .foregroundStyle(Theme.inkSecondary)
        }
    }
}
