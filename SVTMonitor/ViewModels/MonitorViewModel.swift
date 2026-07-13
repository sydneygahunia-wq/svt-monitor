import Foundation
import Combine
import SwiftData

/// A single point in the live sparkline buffer.
struct TracePoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let bpm: Double
}

/// Orchestrates the live monitoring experience: it owns the active
/// `HeartRateProvider`, feeds every sample into the `EpisodeDetector`, and
/// turns detector events into published UI state plus persisted episodes and
/// notifications.
///
/// All mutation happens on the main queue (providers publish there and the
/// Combine sinks `.receive(on:)` the main queue), so the type is safe to use
/// from SwiftUI without a blanket `@MainActor` annotation — which also lets it
/// be constructed in `App.init`.
final class MonitorViewModel: ObservableObject {

    // MARK: Published UI state

    /// Most recent heart rate, rounded, or `nil` before the first reading.
    @Published private(set) var currentBPM: Int?
    @Published private(set) var status: MonitorStatus = .idle
    @Published private(set) var isMonitoring = false
    /// Rolling ~90s window used by the dashboard sparkline.
    @Published private(set) var trace: [TracePoint] = []
    /// Peak BPM of the episode currently in progress (for the status pill).
    @Published private(set) var activePeakBPM: Int?
    @Published private(set) var lastSampleDate: Date?
    /// True while the demo generator is mid-simulated-episode.
    @Published private(set) var isSimulatingEpisode = false

    // MARK: Dependencies

    let settings: AppSettings
    private let detector: EpisodeDetector
    private let notifications = NotificationManager.shared
    private weak var modelContext: ModelContext?

    private var provider: HeartRateProvider?
    private var simulated: SimulatedHeartRateProvider?
    private var sampleCancellable: AnyCancellable?
    private var configCancellables = Set<AnyCancellable>()

    /// How much history the live sparkline retains.
    let traceWindow: TimeInterval = 90

    // MARK: Init

    init(settings: AppSettings) {
        self.settings = settings
        self.detector = EpisodeDetector(config: settings.detectorConfig)
        observeSettings()
    }

    /// Provide the SwiftData context used to persist finished episodes.
    func attach(context: ModelContext) {
        modelContext = context
    }

    /// Whether the active source is the demo generator (controls demo banner).
    var isDemoSource: Bool { settings.dataSource == .demo }

    /// Threshold as a Double for chart rule lines.
    var thresholdBPM: Double { settings.threshold }

    // MARK: Monitoring control

    func startMonitoring() {
        guard !isMonitoring else { return }
        let provider = makeProvider()
        self.provider = provider
        self.simulated = provider as? SimulatedHeartRateProvider

        sampleCancellable = provider.samples
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sample in
                self?.handle(sample)
            }

        detector.reset()
        detector.updateConfig(settings.detectorConfig)
        provider.startStreaming()
        isMonitoring = true
        status = .monitoring
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        provider?.stopStreaming()

        // If we're stopping mid-episode, finalize and record it.
        if let finished = detector.forceEnd(at: lastSampleDate ?? Date()) {
            persist(finished)
        }
        detector.reset()

        sampleCancellable?.cancel()
        sampleCancellable = nil
        provider = nil
        simulated = nil

        isMonitoring = false
        status = .idle
        activePeakBPM = nil
        isSimulatingEpisode = false
    }

    func toggleMonitoring() {
        isMonitoring ? stopMonitoring() : startMonitoring()
    }

    /// Demo-only: kick off a simulated SVT episode.
    func triggerDemoEpisode() {
        simulated?.triggerEpisode()
        isSimulatingEpisode = simulated?.isSimulatingEpisode ?? false
    }

    // MARK: Sample handling

    private func handle(_ sample: HeartRateSample) {
        currentBPM = sample.displayBPM
        lastSampleDate = sample.date
        isSimulatingEpisode = simulated?.isSimulatingEpisode ?? false

        appendToTrace(sample)

        if let event = detector.process(sample) {
            react(to: event)
        }
    }

    private func react(to event: EpisodeDetector.Event) {
        switch event {
        case .started(let summary):
            status = .episode
            activePeakBPM = Int(summary.peakBPM.rounded())
        case .updated(let summary):
            status = .episode
            activePeakBPM = Int(summary.peakBPM.rounded())
        case .ended(let episode):
            persist(episode)
            status = isMonitoring ? .monitoring : .idle
            activePeakBPM = nil
        }
    }

    private func appendToTrace(_ sample: HeartRateSample) {
        trace.append(TracePoint(date: sample.date, bpm: sample.bpm))
        let cutoff = sample.date.addingTimeInterval(-traceWindow)
        trace.removeAll { $0.date < cutoff }
    }

    // MARK: Persistence

    private func persist(_ episode: EpisodeDetector.DetectedEpisode) {
        guard let modelContext else { return }
        let model = SVTEpisode(
            startDate: episode.startDate,
            endDate: episode.endDate,
            peakBPM: episode.peakBPM,
            avgBPM: episode.avgBPM,
            sampleCount: episode.sampleCount,
            hrTrace: episode.hrTrace
        )
        modelContext.insert(model)
        try? modelContext.save()

        notifications.notifyEpisodeRecorded(
            durationText: SVTEpisode.format(duration: episode.duration),
            peakBPM: Int(episode.peakBPM.rounded())
        )
    }

    // MARK: Wiring

    private func makeProvider() -> HeartRateProvider {
        switch settings.dataSource {
        case .demo:
            return SimulatedHeartRateProvider()
        case .healthKit:
            return HealthKitHeartRateProvider()
        }
    }

    private func observeSettings() {
        // Keep the detector's tuning in sync with Settings.
        Publishers.CombineLatest(settings.$threshold, settings.$onsetDelta)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] threshold, onsetDelta in
                self?.detector.updateConfig(
                    EpisodeDetector.Config(threshold: threshold, onsetDelta: onsetDelta)
                )
            }
            .store(in: &configCancellables)

        // Rebuild the stream if the data source changes mid-session.
        settings.$dataSource
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.isMonitoring else { return }
                self.stopMonitoring()
                self.startMonitoring()
            }
            .store(in: &configCancellables)
    }
}
