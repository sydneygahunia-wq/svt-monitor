import SwiftUI
import SwiftData

/// App entry point. Wires up the shared SwiftData container, user settings and
/// the monitor view model, then hands off to `RootView`.
@main
struct SVTMonitorApp: App {

    @StateObject private var settings: AppSettings
    @StateObject private var monitor: MonitorViewModel
    private let container: ModelContainer

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _monitor = StateObject(wrappedValue: MonitorViewModel(settings: settings))

        do {
            // Symptom / trigger / severity fields were added to `SVTEpisode`
            // after v1.0. They all carry defaults, so SwiftData handles this as
            // a lightweight migration and existing episode history is kept.
            container = try ModelContainer(for: SVTEpisode.self)
        } catch {
            fatalError("Failed to create the SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(monitor)
                .tint(Theme.blueDeep)
        }
        .modelContainer(container)
    }
}
