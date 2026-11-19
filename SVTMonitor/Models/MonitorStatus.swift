import SwiftUI

/// High-level monitoring state surfaced to the UI.
enum MonitorStatus: Equatable {
    /// Not currently streaming heart-rate data.
    case idle
    /// Streaming and within a normal range.
    case monitoring
    /// A possible SVT episode is in progress.
    case episode

    var label: String {
        switch self {
        case .idle: return "Not monitoring"
        case .monitoring: return "Monitoring"
        case .episode: return "Possible episode"
        }
    }

    var tint: Color {
        switch self {
        case .idle: return Theme.inkSecondary
        case .monitoring: return Theme.ok
        case .episode: return Theme.alert
        }
    }
}
