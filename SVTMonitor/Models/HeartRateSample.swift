import Foundation

/// A single heart-rate reading flowing through the app.
///
/// Samples come from either HealthKit (Apple Watch) or the built-in demo
/// generator. They are intentionally lightweight value types so the detector
/// and view model can pass them around cheaply.
struct HeartRateSample: Identifiable, Equatable, Hashable {

    /// Where a sample originated.
    enum Source: String, Codable, Equatable, Hashable {
        case healthKit
        case simulated

        var displayName: String {
            switch self {
            case .healthKit: return "Apple Watch"
            case .simulated: return "Demo"
            }
        }
    }

    let id: UUID
    /// Beats per minute.
    let bpm: Double
    /// The instant the reading was taken.
    let date: Date
    let source: Source

    init(id: UUID = UUID(), bpm: Double, date: Date, source: Source) {
        self.id = id
        self.bpm = bpm
        self.date = date
        self.source = source
    }

    /// BPM rounded for display.
    var displayBPM: Int { Int(bpm.rounded()) }
}
