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
