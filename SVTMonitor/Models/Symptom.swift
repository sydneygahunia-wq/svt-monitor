import Foundation

/// A symptom the user can attach to an episode.
///
/// Stored on `SVTEpisode` as raw strings so SwiftData persists a simple
/// `[String]`, while the rest of the app works with the typed enum.
/// Cases are deliberately worded the way patients describe them, not the way
/// a chart would, because the person tagging an episode has just lived through
/// it and may still be shaky.
enum Symptom: String, CaseIterable, Identifiable, Codable {
    case palpitations
    case lightheaded
    case shortnessOfBreath
    case chestPressure
    case anxiety
    case nausea
    case sweating
    case fatigue
    case nearFainting
    case chestPain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .palpitations:      return "Palpitations"
        case .lightheaded:       return "Lightheaded"
        case .shortnessOfBreath: return "Short of breath"
        case .chestPressure:     return "Chest pressure"
        case .anxiety:           return "Anxiety"
        case .nausea:            return "Nausea"
        case .sweating:          return "Sweating"
        case .fatigue:           return "Fatigue"
        case .nearFainting:      return "Nearly fainted"
        case .chestPain:         return "Chest pain"
        }
    }

    var systemImage: String {
        switch self {
        case .palpitations:      return "waveform.path.ecg"
        case .lightheaded:       return "figure.walk.motion"
        case .shortnessOfBreath: return "wind"
        case .chestPressure:     return "arrow.down.to.line.compact"
        case .anxiety:           return "brain.head.profile"
        case .nausea:            return "drop.triangle"
        case .sweating:          return "humidity"
        case .fatigue:           return "zzz"
        case .nearFainting:      return "exclamationmark.triangle"
        case .chestPain:         return "bolt.heart"
        }
    }

    /// Symptoms that warrant urgent care guidance if reported.
    ///
    /// This does not diagnose anything — it only decides whether the app
    /// surfaces a reminder about when to seek help.
    var isRedFlag: Bool {
        switch self {
        case .chestPain, .nearFainting: return true
        default: return false
        }
    }
}
