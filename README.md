# SVT Monitor

An iOS heart-monitoring app that watches heart-rate patterns, flags possible
**SVT (supraventricular tachycardia)** episodes with threshold-based alerting,
and keeps a clear, patient-friendly log of each episode — its timestamp,
duration, and peak BPM.

Built with **Swift, SwiftUI, HealthKit, SwiftData and Swift Charts** for
iOS 17. Designed to read live **Apple Watch** heart-rate data on device, with a
built-in demo mode so the whole experience works without a watch (and in the
simulator).

> **Important:** SVT Monitor is a personal tracking tool, **not a medical
> device**. It does not diagnose, treat, or prevent any condition. Always
> consult your care team about symptoms.

---

## What it does

- **Live monitoring** — a calm dashboard with a heart that beats at your actual
  current rate, a status pill (MONITORING / POSSIBLE EPISODE), and a rolling
  90-second sparkline with the alert threshold drawn in.
- **Automatic episode detection** — a threshold state machine records an episode
  when your heart rate is sustained at/above the threshold *or* rises suddenly
  (both hallmarks of SVT), and closes it once the rate settles back down.
- **Threshold-based alerting** — when an episode is recorded you get a local
  notification: *"Possible SVT episode recorded — 2m 14s, peak 182 BPM."*
- **Episode tracking** — every episode is stored with its start timestamp,
  duration, peak BPM, average BPM, and a heart-rate trace you can chart.
- **Trends** — episodes-per-week bars and peak-BPM-over-time scatter across a
  selectable 30 / 90 / all-time range.
- **Tunable + honest** — adjustable threshold and sudden-onset sensitivity, a
  data-source switch (Apple Watch vs. Demo), permission controls, and a plainly
  worded medical disclaimer.

---

## How to run

1. Open **`SVTMonitor.xcodeproj`** in Xcode (15.4+).
2. Pick an iOS 17 simulator (or your iPhone) as the run destination.
3. Press **Run**.

In the **simulator the app defaults to Demo mode** (there is no Apple Watch
data), so it comes pre-seeded with a few weeks of realistic history and lets you
press **Trigger episode** on the dashboard to watch detection, alerting, and
recording happen end-to-end. On a **real device it defaults to HealthKit** and
streams live Apple Watch heart rate.

### Command-line build (compile check)

```bash
xcodebuild -project "SVTMonitor.xcodeproj" -scheme SVTMonitor \
  -sdk iphonesimulator17.5 -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

> If no iOS **simulator runtime** is installed yet, the scheme-based command
> above can't resolve a destination and the asset-catalog step can't thin icons.
> To verify the code compiles against the SDK without a runtime, build the
> target directly:
>
> ```bash
> xcodebuild -project "SVTMonitor.xcodeproj" -target SVTMonitor \
>   -sdk iphonesimulator17.5 CODE_SIGNING_ALLOWED=NO \
>   ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
> ```

### Tests

```bash
xcodebuild -project "SVTMonitor.xcodeproj" -scheme SVTMonitor \
  -sdk iphonesimulator17.5 -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```

`EpisodeDetectorTests` covers the onset rule, hysteresis exit, peak/average
correctness, and robustness to duplicate / out-of-order samples. The test target
compiles against the simulator SDK today; running it needs a booted simulator
runtime.

---

## How detection works

The core is `EpisodeDetector` — a pure, unit-tested state machine fed one
`HeartRateSample` at a time. It never touches the UI, database, or
notifications, which keeps it easy to reason about and test.

**Entering an episode** (either rule):

1. **Sustained tachycardia** — `enterConsecutive` (3) samples at/above the
   `threshold` (default **150 BPM**).
2. **Sudden onset** — a rise of `onsetDelta` (default **+40 BPM**) within 60s
   once the rate is elevated. SVT classically starts abruptly, so this catches
   an episode a little earlier than the sustained rule.

**Staying in / leaving** — hysteresis: a brief dip doesn't end the episode. It
closes only after `exitConsecutive` (4) consecutive samples fall below
`threshold − 10`. The episode's peak, average, sample count and down-sampled
trace (≤120 points) are computed over the tachycardic samples, and the end time
is the moment the rate first dropped.

The detector is robust to **duplicate and out-of-order** samples (anything at or
before the last processed timestamp is ignored) and to non-positive readings.

---

## Architecture (MVVM)

```
SVTMonitor/
├── App/
│   └── SVTMonitorApp.swift          @main; builds the SwiftData container,
│                                    settings, and monitor view model
├── Models/
│   ├── HeartRateSample.swift        value type: bpm, date, source
│   ├── SVTEpisode.swift             @Model: timestamps, peak/avg BPM, trace, notes
│   ├── MonitorStatus.swift          idle / monitoring / episode
│   └── AppSettings.swift            persisted threshold, onset delta, data source
├── Services/
│   ├── HeartRateProvider.swift      protocol (Combine publisher of samples)
│   ├── HealthKitHeartRateProvider.swift   live Apple Watch data (anchored query)
│   ├── SimulatedHeartRateProvider.swift   demo generator (baseline + SVT episodes)
│   ├── EpisodeDetector.swift        pure threshold state machine (unit-tested)
│   ├── NotificationManager.swift    lazy local-notification permission + delivery
│   └── SeedData.swift               realistic demo history on first launch
├── ViewModels/
│   └── MonitorViewModel.swift       wires provider → detector → UI/persistence
├── Views/
│   ├── RootView.swift               onboarding gate + 4-tab layout
│   ├── DashboardView.swift          live BPM, beating heart, sparkline, controls
│   ├── EpisodeListView.swift        newest-first list, swipe/menu delete
│   ├── EpisodeDetailView.swift      stats, trace chart, editable notes
│   ├── TrendsView.swift             per-week bars + peak scatter, range picker
│   ├── SettingsView.swift           tuning, permissions, disclaimer, about
│   ├── OnboardingView.swift         3-page intro shown once
│   └── Components/                  PulsingHeartView, pills, chips, previews
├── Theme/
│   └── Theme.swift                  brand palette, typography, card styling
└── Resources/
    ├── Info.plist                   HealthKit usage strings, portrait, launch
    ├── SVTMonitor.entitlements      HealthKit entitlement
    └── Assets.xcassets              app icon + brand colors
```

**Data flow:** `HeartRateProvider` (HealthKit or Simulated) publishes samples →
`MonitorViewModel` updates the live UI and feeds each sample to
`EpisodeDetector` → on a finished episode the view model persists an
`SVTEpisode` via SwiftData and posts a notification. Views read episodes
directly with SwiftData `@Query`.

---

## Notes on the project file

The Xcode project is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (a prebuilt binary lives in
`xcodegen/`). The committed `SVTMonitor.xcodeproj` is pinned to
`objectVersion = 56` so it opens in Xcode 15.4. If you regenerate with
`xcodegen generate`, re-apply that pin:

```bash
sed -i '' 's/objectVersion = 77;/objectVersion = 56;/' \
  SVTMonitor.xcodeproj/project.pbxproj
```
