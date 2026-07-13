import SwiftUI
import HealthKit
import UserNotifications

/// Tuning, permissions, disclaimer and about. Kept deliberately plain-spoken so
/// a patient can understand exactly what each control does.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var notifications = NotificationManager.shared

    @State private var hkProvider = HealthKitHeartRateProvider()
    @State private var hkStatus: HKAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    detectionCard
                    dataSourceCard
                    notificationsCard
                    disclaimerCard
                    aboutCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Settings")
            .onAppear {
                hkStatus = hkProvider.authorizationStatus()
                notifications.refreshStatus()
            }
        }
    }

    // MARK: Detection

    private var detectionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Detection")

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Alert threshold")
                            .font(Theme.rounded(16, .semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(Int(settings.threshold)) BPM")
                            .font(Theme.rounded(16, .bold))
                            .foregroundStyle(Theme.blueDeep)
                    }
                    Slider(value: $settings.threshold, in: 120...200, step: 1)
                        .tint(Theme.blue)
                    Text("Sustained readings at or above this rate count toward a possible episode.")
                        .font(Theme.rounded(13))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().background(Theme.hairline)

                VStack(alignment: .leading, spacing: 8) {
                    Stepper(value: $settings.onsetDelta, in: 20...80, step: 5) {
                        HStack {
                            Text("Sudden-onset rise")
                                .font(Theme.rounded(16, .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text("+\(Int(settings.onsetDelta)) BPM")
                                .font(Theme.rounded(16, .bold))
                                .foregroundStyle(Theme.blueDeep)
                        }
                    }
                    Text("A jump this large within 60 seconds flags an episode early, since SVT tends to start abruptly.")
                        .font(Theme.rounded(13))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Data source

    private var dataSourceCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Data source")

                Picker("Data source", selection: $settings.dataSource) {
                    ForEach(DataSource.allCases) { source in
                        Text(source.displayName).tag(source)
                    }
                }
                .pickerStyle(.segmented)

                if settings.dataSource == .healthKit {
                    HStack(spacing: 12) {
                        statusDot(healthKitAuthorized)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Health access")
                                .font(Theme.rounded(15, .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(hkStatusText)
                                .font(Theme.rounded(13))
                                .foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                        Button("Request") {
                            hkProvider.requestAuthorization { _, _ in
                                hkStatus = hkProvider.authorizationStatus()
                            }
                        }
                        .font(Theme.rounded(14, .semibold))
                        .foregroundStyle(Theme.blueDeep)
                    }
                    Text("Heart-rate data comes from your Apple Watch via Apple Health.")
                        .font(Theme.rounded(13))
                        .foregroundStyle(Theme.inkSecondary)
                } else {
                    Text("Demo mode generates a lifelike heart-rate signal so you can explore the app without an Apple Watch.")
                        .font(Theme.rounded(13))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var healthKitAuthorized: Bool { hkStatus == .sharingAuthorized }

    private var hkStatusText: String {
        guard HealthKitHeartRateProvider.isHealthDataAvailable else {
            return "Health data isn't available on this device"
        }
        switch hkStatus {
        case .notDetermined: return "Not requested yet"
        case .sharingDenied: return "Read access not granted"
        case .sharingAuthorized: return "Authorized"
        @unknown default: return "Unknown"
        }
    }

    // MARK: Notifications

    private var notificationsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Notifications")
                HStack(spacing: 12) {
                    statusDot(notifications.authorizationStatus == .authorized)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Episode alerts")
                            .font(Theme.rounded(15, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(notificationStatusText)
                            .font(Theme.rounded(13))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer()
                    if notifications.authorizationStatus == .notDetermined {
                        Button("Enable") {
                            notifications.requestAuthorization { _ in }
                        }
                        .font(Theme.rounded(14, .semibold))
                        .foregroundStyle(Theme.blueDeep)
                    }
                }
            }
        }
    }

    private var notificationStatusText: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "On — you'll be told when an episode is recorded"
        case .denied: return "Off — enable in the Settings app to get alerts"
        case .notDetermined: return "Not set up yet"
        @unknown default: return "Unknown"
        }
    }

    // MARK: Disclaimer

    private var disclaimerCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(Theme.peachDeep)
                    Text("Important")
                        .font(Theme.rounded(16, .bold))
                        .foregroundStyle(Theme.ink)
                }
                Text("SVT Monitor is a personal tracking tool, not a medical device. It does not diagnose, treat, or prevent any condition. Always consult your care team about symptoms.")
                    .font(Theme.rounded(14))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: About

    private var aboutCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "About")
                HStack {
                    Text("Version")
                        .font(Theme.rounded(15, .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("1.0")
                        .font(Theme.rounded(15, .semibold))
                        .foregroundStyle(Theme.inkSecondary)
                }
                Divider().background(Theme.hairline)
                HStack {
                    Text("Built by")
                        .font(Theme.rounded(15, .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("Sydney Gahunia")
                        .font(Theme.rounded(15, .semibold))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
    }

    // MARK: Helpers

    private func statusDot(_ on: Bool) -> some View {
        Circle()
            .fill(on ? Theme.blue : Theme.hairline)
            .frame(width: 12, height: 12)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
