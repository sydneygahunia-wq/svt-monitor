import SwiftUI
import Charts

/// The home screen: a big, calm live heart-rate readout with a beating heart,
/// current status, a rolling sparkline, and monitoring controls.
struct DashboardView: View {
    @EnvironmentObject private var vm: MonitorViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    sparklineCard
                    if vm.isDemoSource { demoCard }
                    monitorButton
                    footnote
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Live Monitor")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Demo mode starts streaming immediately so the app is alive
                // the moment it opens; on-device HealthKit stays opt-in.
                if vm.isDemoSource && !vm.isMonitoring { vm.startMonitoring() }
            }
        }
    }

    // MARK: Hero

    private var heartTint: Color {
        switch vm.status {
        case .episode: return Theme.peach
        case .monitoring: return Theme.blue
        case .idle: return Theme.blue.opacity(0.45)
        }
    }

    private var heroCard: some View {
        Card(padding: 24) {
            VStack(spacing: 18) {
                StatusPill(status: vm.status)

                ZStack {
                    PulsingHeartView(bpm: displayBPM, tint: heartTint)
                        .frame(width: 200, height: 200)
                    VStack(spacing: 0) {
                        Text(bpmText)
                            .font(Theme.rounded(66, .heavy))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: vm.currentBPM)
                        Text("BPM")
                            .font(Theme.rounded(15, .bold))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .offset(y: 4)
                }
                .frame(height: 210)

                Text(lastUpdatedText)
                    .font(Theme.rounded(13, .medium))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Only pulse to a live rate while actually monitoring.
    private var displayBPM: Int? { vm.isMonitoring ? vm.currentBPM : nil }

    private var bpmText: String {
        guard vm.isMonitoring, let bpm = vm.currentBPM else { return "--" }
        return "\(bpm)"
    }

    private var lastUpdatedText: String {
        guard vm.isMonitoring else { return "Tap Start monitoring to begin" }
        if vm.status == .episode {
            return "Possible SVT episode in progress"
        }
        if let date = vm.lastSampleDate {
            return "Updated \(date.formatted(date: .omitted, time: .standard))"
        }
        return "Waiting for the first reading…"
    }

    // MARK: Sparkline

    private var sparklineCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Last 90 seconds")
                    Spacer()
                    Text("Threshold \(Int(vm.thresholdBPM)) BPM")
                        .font(Theme.rounded(11, .semibold))
                        .foregroundStyle(Theme.peachDeep)
                }

                if vm.trace.isEmpty {
                    placeholderChart
                } else {
                    liveChart
                }
            }
        }
    }

    private var liveChart: some View {
        Chart {
            ForEach(vm.trace) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("BPM", point.bpm)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(vm.status == .episode ? Theme.peachDeep : Theme.blueDeep)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("BPM", point.bpm)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [(vm.status == .episode ? Theme.peach : Theme.blue).opacity(0.35), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            RuleMark(y: .value("Threshold", vm.thresholdBPM))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(Theme.peach.opacity(0.9))
        }
        .chartYScale(domain: chartYDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))")
                            .font(Theme.rounded(10))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
        }
        .frame(height: 150)
    }

    private var chartYDomain: ClosedRange<Double> {
        let bpms = vm.trace.map(\.bpm)
        let lo = min((bpms.min() ?? 60) - 10, vm.thresholdBPM - 10)
        let hi = max((bpms.max() ?? 120) + 10, vm.thresholdBPM + 10)
        return lo...hi
    }

    private var placeholderChart: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.background)
            Text(vm.isMonitoring ? "Collecting readings…" : "No live data yet")
                .font(Theme.rounded(14, .medium))
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(height: 150)
    }

    // MARK: Demo banner

    private var demoCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(Theme.blueDeep)
                    Text("Demo mode")
                        .font(Theme.rounded(16, .bold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                Text("Heart-rate data is simulated. Trigger a sample SVT episode to watch detection, alerting, and episode recording work end-to-end.")
                    .font(Theme.rounded(14))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    vm.triggerDemoEpisode()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "bolt.heart.fill")
                        Text(vm.isSimulatingEpisode ? "Episode in progress…" : "Trigger episode")
                            .font(Theme.rounded(15, .semibold))
                    }
                    .foregroundStyle(Theme.peachDeep)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Theme.peach.opacity(0.25)))
                }
                .disabled(!vm.isMonitoring || vm.isSimulatingEpisode)
                .opacity((!vm.isMonitoring || vm.isSimulatingEpisode) ? 0.55 : 1)
            }
        }
    }

    // MARK: Controls

    private var monitorButton: some View {
        Button {
            vm.toggleMonitoring()
        } label: {
            PrimaryButtonLabel(
                title: vm.isMonitoring ? "Stop monitoring" : "Start monitoring",
                systemImage: vm.isMonitoring ? "stop.fill" : "play.fill",
                tint: vm.isMonitoring ? Theme.inkSecondary : Theme.blueDeep
            )
        }
        .buttonStyle(.plain)
    }

    private var footnote: some View {
        Text("SVT Monitor is a personal tracking tool, not a medical device.")
            .font(Theme.rounded(12))
            .foregroundStyle(Theme.inkSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }
}

#Preview {
    let settings = AppSettings()
    return DashboardView()
        .environmentObject(MonitorViewModel(settings: settings))
}
