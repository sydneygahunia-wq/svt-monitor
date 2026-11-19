import SwiftUI
import Charts

/// The home screen. Laid out like the Watch Heart Rate app: the number first
/// and largest, a plain chart under it, then a short list of things to do.
/// During an episode the screen reorders itself so the breathing guide is the
/// first thing under your thumb.
struct DashboardView: View {
    @EnvironmentObject private var vm: MonitorViewModel

    /// One presentation source for the screen — stacking several `.sheet`
    /// modifiers on the same view is unreliable, so route them through one.
    private enum Sheet: String, Identifiable {
        case calm
        case log
        var id: String { rawValue }
    }

    @State private var sheet: Sheet?

    private var inEpisode: Bool { vm.status == .episode }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    readout
                    if inEpisode {
                        breatheNowButton
                    } else if !vm.isMonitoring {
                        startButton
                    }
                    chartSection
                    actions
                    footnote
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .appBackground()
            .navigationTitle("Monitor")
            .toolbar {
                if vm.isMonitoring {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Stop") { vm.toggleMonitoring() }
                    }
                }
            }
            .onAppear {
                // Demo mode starts streaming immediately so the app is alive
                // the moment it opens; on-device HealthKit stays opt-in.
                if vm.isDemoSource && !vm.isMonitoring { vm.startMonitoring() }
            }
            .sheet(item: $sheet) { which in
                switch which {
                case .calm: CalmModeView().environmentObject(vm)
                case .log:  LogEpisodeView()
                }
            }
            .onChange(of: vm.status) { _, newStatus in
                // When an episode starts, the breathing guide comes to the user
                // rather than expecting them to go looking for it. Hunting
                // through tabs is the last thing anyone wants to do mid-episode.
                if newStatus == .episode && sheet == nil {
                    sheet = .calm
                }
            }
        }
    }

    // MARK: Readout

    private var readout: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                StatusPill(status: vm.status)
                if let updated = updatedText {
                    Text("· \(updated)")
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }

            // Heart, number, unit on one line, as on the Watch.
            HStack(alignment: .center, spacing: 10) {
                PulsingHeartView(bpm: displayBPM, tint: inEpisode ? Theme.alert : Theme.accent)
                    .frame(width: 30, height: 30)
                if let bpm = liveBPM {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(bpm)")
                            .font(Theme.number(80, .semibold))
                            .foregroundStyle(inEpisode ? Theme.alert : Theme.ink)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: bpm)
                        Text("bpm")
                            .font(Theme.font(22, .semibold))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                } else {
                    // A big placeholder dash reads as a broken bar; words don't.
                    Text("No reading")
                        .font(Theme.font(34, .semibold))
                        .foregroundStyle(Theme.inkSecondary)
                        .padding(.vertical, 18)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(vm.currentBPM.map { "\($0) beats per minute" } ?? "No reading")

            if let detail = detailText {
                Text(detail)
                    .font(Theme.font(15))
                    .foregroundStyle(inEpisode ? Theme.alert : Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Only pulse to a live rate while actually monitoring.
    private var displayBPM: Int? { vm.isMonitoring ? vm.currentBPM : nil }

    private var liveBPM: Int? { vm.isMonitoring ? vm.currentBPM : nil }

    private var updatedText: String? {
        guard vm.isMonitoring, let date = vm.lastSampleDate else { return nil }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private var detailText: String? {
        if inEpisode {
            let peak = vm.activePeakBPM.map { ", peak \($0) bpm so far" } ?? ""
            return "Above your \(Int(vm.thresholdBPM)) bpm alert\(peak). This is being recorded."
        }
        if !vm.isMonitoring {
            return vm.isDemoSource
                ? "Demo mode uses a simulated heart rate."
                : "Reads heart rate from your Apple Watch."
        }
        if vm.currentBPM == nil {
            return "Waiting for your watch to send a reading."
        }
        return nil
    }

    // MARK: Primary actions

    private var breatheNowButton: some View {
        Button {
            sheet = .calm
        } label: {
            PrimaryButtonLabel(title: "Start breathing", systemImage: "wind", tint: Theme.calm)
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        Button {
            vm.toggleMonitoring()
        } label: {
            PrimaryButtonLabel(title: "Start monitoring", systemImage: "heart.fill")
        }
        .buttonStyle(.plain)
    }

    // MARK: Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last 90 seconds")
                    .font(Theme.font(17, .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("Alert at \(Int(vm.thresholdBPM))")
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.inkSecondary)
            }

            Card {
                if vm.trace.isEmpty {
                    Text(vm.isMonitoring ? "Collecting readings…" : "Nothing to show yet.")
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 110)
                } else {
                    liveChart
                }
            }
        }
    }

    private var lineColor: Color { inEpisode ? Theme.alert : Theme.accent }

    private var liveChart: some View {
        Chart {
            ForEach(vm.trace) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Floor", chartYDomain.lowerBound),
                    yEnd: .value("BPM", point.bpm)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(lineColor.opacity(0.10))

                LineMark(
                    x: .value("Time", point.date),
                    y: .value("BPM", point.bpm)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            RuleMark(y: .value("Alert", vm.thresholdBPM))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Theme.alertSoft)
        }
        .chartYScale(domain: chartYDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Theme.hairline.opacity(0.6))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))")
                            .font(Theme.number(11, .regular))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
        }
        .frame(height: 150)
        .accessibilityLabel("Heart rate over the last 90 seconds")
    }

    private var chartYDomain: ClosedRange<Double> {
        let bpms = vm.trace.map(\.bpm)
        let lo = min((bpms.min() ?? 60) - 10, vm.thresholdBPM - 10)
        let hi = max((bpms.max() ?? 120) + 10, vm.thresholdBPM + 10)
        return lo...hi
    }

    // MARK: Secondary actions

    private var actions: some View {
        VStack(spacing: 0) {
            if !inEpisode {
                actionRow(title: "Breathe", subtitle: "Paced breathing, any time", systemImage: "wind", tint: Theme.calm) {
                    sheet = .calm
                }
                Divider().padding(.leading, 52)
            }
            actionRow(title: "Log an episode", subtitle: "For one your watch missed", systemImage: "square.and.pencil", tint: Theme.accent) {
                sheet = .log
            }
            if vm.isDemoSource {
                Divider().padding(.leading, 52)
                actionRow(
                    title: vm.isSimulatingEpisode ? "Simulating…" : "Simulate an episode",
                    subtitle: "Demo only: test detection",
                    systemImage: "waveform.path.ecg",
                    tint: Theme.alert
                ) {
                    vm.triggerDemoEpisode()
                }
                .disabled(!vm.isMonitoring || vm.isSimulatingEpisode)
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private func actionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Theme.font(17))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footnote: some View {
        Text("SVT Monitor is a personal tracking tool, not a medical device.")
            .font(Theme.font(12))
            .foregroundStyle(Theme.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

#Preview {
    let settings = AppSettings()
    return DashboardView()
        .environmentObject(MonitorViewModel(settings: settings))
}
