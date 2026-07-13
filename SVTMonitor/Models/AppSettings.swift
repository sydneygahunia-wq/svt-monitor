import Foundation
import Combine

/// The heart-rate source the app should stream from.
enum DataSource: String, CaseIterable, Identifiable {
    case healthKit
    case demo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .healthKit: return "Apple Watch (HealthKit)"
        case .demo: return "Demo"
        }
    }

    /// Sensible default: demo in the simulator (no watch data), HealthKit on device.
    static var deviceDefault: DataSource {
        #if targetEnvironment(simulator)
        return .demo
        #else
        return .healthKit
        #endif
    }
}

/// User-tunable settings, persisted in `UserDefaults` and shared across the app
/// as an `ObservableObject` so Settings and the monitor stay in sync.
final class AppSettings: ObservableObject {

    private enum Keys {
        static let threshold = "settings.threshold"
        static let onsetDelta = "settings.onsetDelta"
        static let dataSource = "settings.dataSource"
    }

    private let defaults: UserDefaults

    /// BPM at/above which readings count toward an episode. Default 150.
    @Published var threshold: Double {
        didSet { defaults.set(threshold, forKey: Keys.threshold) }
    }

    /// Sudden-onset rise (BPM within 60s) that triggers an episode. Default 40.
    @Published var onsetDelta: Double {
        didSet { defaults.set(onsetDelta, forKey: Keys.onsetDelta) }
    }

    /// Which provider to stream from.
    @Published var dataSource: DataSource {
        didSet { defaults.set(dataSource.rawValue, forKey: Keys.dataSource) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Keys.threshold) != nil {
            self.threshold = defaults.double(forKey: Keys.threshold)
        } else {
            self.threshold = 150
        }

        if defaults.object(forKey: Keys.onsetDelta) != nil {
            self.onsetDelta = defaults.double(forKey: Keys.onsetDelta)
        } else {
            self.onsetDelta = 40
        }

        if let raw = defaults.string(forKey: Keys.dataSource),
           let source = DataSource(rawValue: raw) {
            self.dataSource = source
        } else {
            self.dataSource = DataSource.deviceDefault
        }
    }

    /// Detector configuration derived from the current settings.
    var detectorConfig: EpisodeDetector.Config {
        EpisodeDetector.Config(threshold: threshold, onsetDelta: onsetDelta)
    }
}
