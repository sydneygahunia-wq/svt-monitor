import SwiftUI
import HealthKit

/// A short, three-page introduction shown once on first launch. Explains what
/// the app does, how detection works, and asks for permissions alongside the
/// medical disclaimer.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var notifications = NotificationManager.shared

    @State private var page = 0
    @State private var hkProvider = HealthKitHeartRateProvider()

    private let lastPage = 2

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcome.tag(0)
                    howItWorks.tag(1)
                    permissions.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                pageDots
                    .padding(.top, 8)

                controls
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: Pages

    private var welcome: some View {
        pageLayout(
            icon: "heart.text.square.fill",
            iconTint: Theme.blue,
            title: "Welcome to SVT Monitor",
            body: "A calm, private place to keep an eye on your heart. SVT Monitor watches your heart rate and records possible SVT episodes so you have a clear history to share with your care team."
        )
    }

    private var howItWorks: some View {
        pageLayout(
            icon: "waveform.path.ecg",
            iconTint: Theme.peachDeep,
            title: "How detection works",
            body: "You set an alert threshold (default 150 BPM). When your heart rate stays at or above it — or jumps suddenly, the way SVT often begins — the app records an episode with its start time, duration, and peak BPM."
        )
    }

    private var permissions: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.blue)
                    .padding(.top, 20)

                Text("A couple of permissions")
                    .font(Theme.rounded(26, .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    permissionRow(
                        icon: "bell.badge.fill",
                        title: "Episode alerts",
                        subtitle: "Get a gentle notification when an episode is recorded.",
                        buttonTitle: notifications.authorizationStatus == .notDetermined ? "Enable" : "Enabled",
                        enabled: notifications.authorizationStatus == .notDetermined
                    ) {
                        notifications.requestAuthorization { _ in }
                    }

                    if HealthKitHeartRateProvider.isHealthDataAvailable {
                        permissionRow(
                            icon: "heart.fill",
                            title: "Apple Health",
                            subtitle: "Read heart rate from your Apple Watch.",
                            buttonTitle: "Allow",
                            enabled: true
                        ) {
                            hkProvider.requestAuthorization { _, _ in }
                        }
                    }
                }

                disclaimer
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Important")
                .font(Theme.rounded(14, .bold))
                .foregroundStyle(Theme.peachDeep)
            Text("SVT Monitor is a personal tracking tool, not a medical device. It does not diagnose, treat, or prevent any condition. Always consult your care team about symptoms.")
                .font(Theme.rounded(13))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.peach.opacity(0.14))
        )
    }

    // MARK: Reusable page layout

    private func pageLayout(icon: String, iconTint: Color, title: String, body: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(iconTint.opacity(0.15))
                    .frame(width: 150, height: 150)
                Image(systemName: icon)
                    .font(.system(size: 66))
                    .foregroundStyle(iconTint)
            }
            Text(title)
                .font(Theme.rounded(28, .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(body)
                .font(Theme.rounded(16))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 8)
    }

    private func permissionRow(icon: String, title: String, subtitle: String, buttonTitle: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Theme.blueDeep)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.rounded(15, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(Theme.rounded(12))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(buttonTitle, action: action)
                .font(Theme.rounded(14, .semibold))
                .foregroundStyle(enabled ? Theme.blueDeep : Theme.inkSecondary)
                .disabled(!enabled)
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Theme.cardShadow, radius: 8, y: 3)
    }

    // MARK: Controls

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0...lastPage, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Theme.blueDeep : Theme.hairline)
                    .frame(width: i == page ? 22 : 8, height: 8)
                    .animation(.easeInOut, value: page)
            }
        }
    }

    private var controls: some View {
        Button {
            if page < lastPage {
                withAnimation { page += 1 }
            } else {
                hasCompletedOnboarding = true
            }
        } label: {
            PrimaryButtonLabel(
                title: page < lastPage ? "Continue" : "Get started",
                systemImage: page < lastPage ? "arrow.right" : "checkmark"
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppSettings())
}
