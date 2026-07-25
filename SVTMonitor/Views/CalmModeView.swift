import SwiftUI
import UIKit

/// The screen someone opens *during* an episode.
///
/// Design constraints, all of which come from what an episode actually feels
/// like: one thing on screen at a time, text large enough to read with a
/// racing heart, nothing that requires a decision to start, and no way to get
/// lost. The breathing guide begins the moment the screen appears — there is
/// no "begin" button to find.
struct CalmModeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var monitor: MonitorViewModel

    /// Tick rate for the pacing clock. Phase transitions drive the animation,
    /// so this only needs to be fast enough for a smooth countdown.
    private static let tick: TimeInterval = 0.2

    @State private var pattern: BreathingPattern = .box
    @State private var elapsed: TimeInterval = 0
    @State private var currentPhase: BreathingPattern.Phase = .inhale
    @State private var circleScale: CGFloat = Self.smallScale
    @State private var showManeuvers = false

    private static let smallScale: CGFloat = 0.42
    private static let largeScale: CGFloat = 1.0

    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private var state: BreathingPattern.State? { pattern.state(at: elapsed) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    breathingGuide
                    patternPicker
                    if let bpm = monitor.currentBPM {
                        liveRateCard(bpm: bpm)
                    }
                    maneuversSection
                    seekHelpCard
                }
                .padding(20)
            }
            .appBackground()
            .navigationTitle("Calm mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.rounded(17, .semibold))
                }
            }
        }
        .onAppear {
            monitor.noteCalmModeOpened()
            beginPhase(pattern.state(at: 0)?.step.phase ?? .inhale, duration: 0.4)
        }
        .onReceive(timer) { _ in
            elapsed += Self.tick
            syncPhase()
        }
        .onChange(of: pattern) { _, _ in
            elapsed = 0
            beginPhase(pattern.state(at: 0)?.step.phase ?? .inhale, duration: 0.4)
        }
    }

    // MARK: - Breathing guide

    private var breathingGuide: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.blue.opacity(0.14))
                    .frame(width: 260, height: 260)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.blue.opacity(0.85), Theme.blueDeep.opacity(0.55)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 130
                        )
                    )
                    .frame(width: 260, height: 260)
                    .scaleEffect(circleScale)

                VStack(spacing: 6) {
                    Text(currentPhase.instruction)
                        .font(Theme.rounded(26, .bold))
                        .foregroundStyle(.white)
                    if let state {
                        Text("\(state.secondsRemaining)")
                            .font(Theme.rounded(44, .bold))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }
                }
                .shadow(color: Theme.ink.opacity(0.25), radius: 6, y: 2)
            }
            .frame(height: 280)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Breathing guide")
            .accessibilityValue("\(currentPhase.instruction), \(state?.secondsRemaining ?? 0) seconds")

            if let state, state.completedCycles > 0 {
                Text("\(state.completedCycles) breath\(state.completedCycles == 1 ? "" : "s") so far")
                    .font(Theme.rounded(15))
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                Text("Follow the circle. Nothing else to do.")
                    .font(Theme.rounded(15))
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private var patternPicker: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Pace")
                ForEach(BreathingPattern.all) { option in
                    Button {
                        pattern = option
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: pattern.id == option.id ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(pattern.id == option.id ? Theme.blueDeep : Theme.hairline)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(option.name) · \(option.rhythmText)")
                                    .font(Theme.rounded(16, .semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(option.subtitle)
                                    .font(Theme.rounded(13))
                                    .foregroundStyle(Theme.inkSecondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func liveRateCard(bpm: Int) -> some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.peachDeep)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(bpm) BPM")
                        .font(Theme.rounded(24, .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Current rate")
                        .font(Theme.rounded(13))
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 0)
                StatusPill(status: monitor.status)
            }
        }
    }

    // MARK: - Maneuvers

    private var maneuversSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showManeuvers.toggle() }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Maneuver reminders")
                                .font(Theme.rounded(17, .bold))
                                .foregroundStyle(Theme.ink)
                            Text("Only what your care team taught you")
                                .font(Theme.rounded(13))
                                .foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: showManeuvers ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showManeuvers {
                    Text(VagalManeuver.disclaimer)
                        .font(Theme.rounded(14))
                        .foregroundStyle(Theme.ink)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.peach.opacity(0.25))
                        )

                    ForEach(VagalManeuver.all) { maneuver in
                        maneuverRow(maneuver)
                    }

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.peachDeep)
                        Text(VagalManeuver.neverDoAlone)
                            .font(Theme.rounded(13, .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func maneuverRow(_ maneuver: VagalManeuver) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: maneuver.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.blueDeep)
                Text(maneuver.title)
                    .font(Theme.rounded(16, .bold))
                    .foregroundStyle(Theme.ink)
            }

            Text(maneuver.precondition)
                .font(Theme.rounded(13, .semibold))
                .foregroundStyle(Theme.peachDeep)

            ForEach(Array(maneuver.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(Theme.rounded(14, .semibold))
                        .foregroundStyle(Theme.inkSecondary)
                    Text(step)
                        .font(Theme.rounded(14))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.background)
        )
    }

    private var seekHelpCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "cross.case.fill")
                        .foregroundStyle(Theme.peachDeep)
                    Text("Get help now if you have")
                        .font(Theme.rounded(17, .bold))
                        .foregroundStyle(Theme.ink)
                }

                ForEach(VagalManeuver.seekHelpPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Theme.peachDeep)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(point)
                            .font(Theme.rounded(15))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(VagalManeuver.seekHelpFooter)
                    .font(Theme.rounded(14, .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Pacing

    private func syncPhase() {
        guard let state else { return }
        guard state.step.phase != currentPhase else { return }
        beginPhase(state.step.phase, duration: state.step.duration)
    }

    /// Animate the guide circle toward the target size for `phase`, over the
    /// phase's own duration, so the visual pace *is* the breathing pace.
    private func beginPhase(_ phase: BreathingPattern.Phase, duration: TimeInterval) {
        currentPhase = phase
        let target: CGFloat = (phase == .inhale || phase == .holdIn)
            ? Self.largeScale
            : Self.smallScale

        withAnimation(.easeInOut(duration: max(duration, 0.2))) {
            circleScale = target
        }

        // A light tap on each change means the guide can be followed with your
        // eyes shut, which is how most people want to use it.
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

#Preview {
    CalmModeView()
        .environmentObject(MonitorViewModel(settings: AppSettings()))
}
