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
        case .idle: return "NOT MONITORING"
        case .monitoring: return "MONITORING"
        case .episode: return "POSSIBLE EPISODE"
        }
    }

    var tint: Color {
        switch self {
        case .idle: return Theme.inkSecondary
        case .monitoring: return Theme.blueDeep
        case .episode: return Theme.peachDeep
        }
    }

    var fill: Color {
        switch self {
        case .idle: return Theme.hairline
        case .monitoring: return Theme.blue.opacity(0.22)
        case .episode: return Theme.peach.opacity(0.35)
        }
    }
}
