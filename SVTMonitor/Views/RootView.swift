import SwiftUI
import SwiftData

/// Gates onboarding vs. the main app.
struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        // Theme fonts are resolved for the text size in effect when they're
        // built, so rebuild when the user changes it in Settings.
        .id(dynamicTypeSize)
    }
}

/// The four-tab main interface.
struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: MonitorViewModel

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Monitor", systemImage: "heart.fill") }

            EpisodeListView()
                .tabItem { Label("Episodes", systemImage: "list.bullet.rectangle.portrait.fill") }

            TrendsView()
                .tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.accent)
        .onAppear {
            monitor.attach(context: context)
            // Populate demo history the first time we run in demo mode.
            if settings.dataSource == .demo {
                SeedData.seedIfNeeded(context: context)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppSettings())
        .environmentObject(MonitorViewModel(settings: AppSettings()))
        .modelContainer(PreviewData.container)
}
