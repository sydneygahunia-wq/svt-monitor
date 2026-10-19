# SVT Monitor

An iOS app for living with **SVT (supraventricular tachycardia)**. It watches
heart-rate patterns and flags possible episodes with threshold-based alerting,
guides you through paced breathing while an episode is happening, and keeps a
clear, patient-friendly log of each one — timestamp, duration, peak BPM, the
symptoms you felt and anything that might have set it off — so you have
something concrete to show your care team.

Built with **Swift, SwiftUI, HealthKit, SwiftData and Swift Charts** for
iOS 17. Designed to read live **Apple Watch** heart-rate data on device, with a
built-in demo mode so the whole experience works without a watch (and in the
simulator).

> **Important:** SVT Monitor is a personal tracking tool, **not a medical
> device**. It does not diagnose, treat, or prevent any condition. Always
> consult your care team about symptoms.

---

## Screenshots

| Live Monitor | Episode Log | Onboarding |
|:---:|:---:|:---:|
| ![Live dashboard with beating heart and threshold sparkline](docs/dashboard.png) | ![Episode history with durations and peak BPM](docs/episodes.png) | ![Onboarding](docs/onboarding.png) |

---

## What it does

### App Features

**Live Heart Rate Monitoring**

A simple dashboard that shows your current heart rate with an animated heart that beats at the same pace. It also shows whether your heart rate is normal or if a possible episode is happening. A graph displays your heart rate over the last 90 seconds along with your alert threshold.

**Automatic Episode Detection**

The app monitors your heart rate and detects possible SVT episodes when it stays above a certain threshold or suddenly increases. Once your heart rate returns to normal, the app automatically records when the episode ended.

**Episode Alerts**

When a possible episode is detected, the app sends a notification showing how long it lasted and the highest heart rate recorded.

**Episode History**

Every episode is saved with its start time, duration, highest heart rate and average heart rate. Users can also view a graph of how their heart rate changed throughout the episode.

**Heart Rate Trends**

A trends page helps users understand how their episodes change over time. It includes graphs showing how often episodes happen and the highest heart rates recorded. Users can view data from the past 30 days, 90 days or their entire history.

**Calm Mode**

When an episode is detected, the app automatically opens a calming screen. Users can follow guided breathing exercises while still seeing their current heart rate. It also includes reminders of techniques recommended by their healthcare provider and information about when to seek medical help.

**Symptom and Trigger Tracking**

After an episode, users can record symptoms such as dizziness or chest pressure. They can also log possible triggers like caffeine, stress, exercise or lack of sleep. Users can rate how severe the episode felt on a scale of 1 to 5.

**Manual Episode Logging**

Not everyone wears their Apple Watch all the time. Users can manually add episodes they experienced without their watch and include any details they remember.

**Pattern Tracking**

The app looks at previously recorded episodes to show which symptoms and possible triggers appear most often. This helps users recognize patterns without assuming that a particular trigger caused an episode.

**Appointment Summaries**

Users can export a summary of their episodes to share with their healthcare provider. The summary includes episode frequency, duration, heart rate measurements and recorded symptoms.

**Customizable Settings**

Users can adjust their heart rate thresholds and detection sensitivity. They can also switch between Apple Watch data and simulated data for testing. The app includes permission settings and a reminder that it is not a replacement for professional medical care.

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

The test target covers the parts of the app where being wrong actually matters:

| Suite | Covers |
| --- | --- |
| `EpisodeDetectorTests` | Onset rule, hysteresis exit, peak/average correctness, duplicate and out-of-order samples |
| `BreathingPatternTests` | Phase ordering, cycle wrap-around, countdown rounding, zero-length and empty patterns, negative clock input |
| `EpisodeInsightsTests` | Averages, severity exclusion, tag ranking and tie-breaking, duplicate/unknown raw tags, appointment-summary contents |
| `SVTEpisodeTaggingTests` | Tag round-trip through `[String]` storage, unknown-value handling, red-flag detection, severity labels |

The test target compiles against the simulator SDK today; running it needs a
booted simulator runtime.

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
│   ├── SVTEpisode.swift             @Model: timestamps, peak/avg BPM, trace,
│   │                                notes, symptoms, triggers, severity
│   ├── Symptom.swift                what an episode felt like
│   ├── EpisodeTrigger.swift         what may have preceded it
│   ├── VagalManeuver.swift          reminder content + safety guidance
│   ├── MonitorStatus.swift          idle / monitoring / episode
│   └── AppSettings.swift            persisted threshold, onset delta, data source
├── Services/
│   ├── HeartRateProvider.swift      protocol (Combine publisher of samples)
│   ├── HealthKitHeartRateProvider.swift   live Apple Watch data (anchored query)
│   ├── SimulatedHeartRateProvider.swift   demo generator (baseline + SVT episodes)
│   ├── EpisodeDetector.swift        pure threshold state machine (unit-tested)
│   ├── BreathingPattern.swift       pure paced-breathing clock (unit-tested)
│   ├── EpisodeInsights.swift        pure tag/stat analysis + export (unit-tested)
│   ├── NotificationManager.swift    lazy local-notification permission + delivery
│   └── SeedData.swift               realistic demo history on first launch
├── ViewModels/
│   └── MonitorViewModel.swift       wires provider → detector → UI/persistence
├── Views/
│   ├── RootView.swift               onboarding gate + 4-tab layout
│   ├── DashboardView.swift          live BPM, beating heart, sparkline, controls
│   ├── CalmModeView.swift           breathing guide, maneuver reminders, help card
│   ├── LogEpisodeView.swift         manual episode entry
│   ├── EpisodeListView.swift        newest-first list, swipe/menu delete
│   ├── EpisodeDetailView.swift      stats, trace chart, tags, notes
│   ├── TrendsView.swift             per-week bars, peak scatter, tag patterns
│   ├── SettingsView.swift           tuning, permissions, disclaimer, about
│   ├── OnboardingView.swift         4-page intro shown once
│   └── Components/                  heart, pills, tag chips, flow layout, share
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

Detection status also drives presentation: when `MonitorViewModel.status`
becomes `.episode`, the dashboard presents **Calm Mode** without waiting to be
asked, because navigating an app is the last thing anyone wants to do
mid-episode. If the breathing guide is opened during an episode, the saved
`SVTEpisode` records that too.

---

## A note on the maneuver reminders

Calm Mode lists vagal maneuvers, and it is worth being explicit about what that
is and isn't. The app does **not** teach these techniques and does not decide
they are appropriate for you — that is a conversation with a cardiologist. Every
entry is prefaced with the condition under which it applies ("only if your
cardiologist has taught you this version"), the list is fronted by a
non-dismissible disclaimer, and self-administered carotid massage is explicitly
called out as something never to do alone rather than quietly left off the list.
Alongside it sits a plain list of when to stop and call emergency services.

The intent is recall support for something already taught, at the moment recall
is hardest — not instruction.

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
