import Foundation
import UserNotifications

/// Thin wrapper over `UNUserNotificationCenter` for the app's one notification
/// type: a gentle heads-up when a possible SVT episode has been recorded.
///
/// Permission is requested lazily — the first time we actually have something
/// to notify about — so the patient isn't prompted before the app has proven
/// useful.
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        refreshStatus()
    }

    /// Refresh the cached authorization status (published for Settings).
    func refreshStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    /// Explicitly ask for permission (used by Settings / onboarding).
    func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.refreshStatus()
                completion?(granted)
            }
        }
    }

    /// Post an episode-recorded notification, requesting permission first if it
    /// hasn't been decided yet.
    func notifyEpisodeRecorded(durationText: String, peakBPM: Int) {
        deliver(durationText: durationText, peakBPM: peakBPM)
    }

    private func deliver(durationText: String, peakBPM: Int) {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .notDetermined:
                self.requestAuthorization { granted in
                    if granted { self.post(durationText: durationText, peakBPM: peakBPM) }
                }
            case .authorized, .provisional, .ephemeral:
                self.post(durationText: durationText, peakBPM: peakBPM)
            default:
                break // Denied — respect the patient's choice silently.
            }
        }
    }

    private func post(durationText: String, peakBPM: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Possible SVT episode recorded"
        content.body = "\(durationText), peak \(peakBPM) BPM. Tap to review the details."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver right away
        )
        center.add(request, withCompletionHandler: nil)
    }
}
