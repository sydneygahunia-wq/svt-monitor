import Foundation

/// A possible trigger the user can attach to an episode.
///
/// The point of tracking these is pattern-finding over time: one episode after
/// coffee means nothing, but nine out of twelve is a conversation worth having
/// with a cardiologist.
enum EpisodeTrigger: String, CaseIterable, Identifiable, Codable {
    case caffeine
    case alcohol
    case stress
    case exercise
    case dehydration
    case poorSleep
    case illness
    case largeMeal
    case positionChange
    case hormonal
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .caffeine:       return "Caffeine"
        case .alcohol:        return "Alcohol"
        case .stress:         return "Stress"
        case .exercise:       return "Exercise"
        case .dehydration:    return "Dehydration"
        case .poorSleep:      return "Poor sleep"
        case .illness:        return "Illness"
        case .largeMeal:      return "Large meal"
        case .positionChange: return "Bending / position change"
        case .hormonal:       return "Hormonal"
        case .unknown:        return "Not sure"
        }
    }

    var systemImage: String {
        switch self {
        case .caffeine:       return "cup.and.saucer.fill"
        case .alcohol:        return "wineglass.fill"
        case .stress:         return "bolt.fill"
        case .exercise:       return "figure.run"
        case .dehydration:    return "drop.fill"
        case .poorSleep:      return "moon.zzz.fill"
        case .illness:        return "thermometer.medium"
        case .largeMeal:      return "fork.knife"
        case .positionChange: return "figure.flexibility"
        case .hormonal:       return "calendar"
        case .unknown:        return "questionmark.circle"
        }
    }
}
