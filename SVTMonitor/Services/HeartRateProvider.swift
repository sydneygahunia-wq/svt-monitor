import Foundation
import Combine

/// Abstraction over a live heart-rate source.
///
/// Two implementations exist: `HealthKitHeartRateProvider` (real Apple Watch
/// data) and `SimulatedHeartRateProvider` (demo mode). The view model depends
/// only on this protocol, which keeps detection logic testable and the UI
/// source-agnostic.
protocol HeartRateProvider: AnyObject {

    /// Emits every new heart-rate sample while streaming.
    var samples: AnyPublisher<HeartRateSample, Never> { get }

    /// The source these samples represent.
    var source: HeartRateSample.Source { get }

    /// Begin streaming. Safe to call more than once.
    func startStreaming()

    /// Stop streaming and release any underlying queries/timers.
    func stopStreaming()
}
