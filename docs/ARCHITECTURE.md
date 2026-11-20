# SVT Monitor: design notes

The details behind the [README](../README.md).

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

## Accessibility

Someone opening this app may be mid-episode, dizzy, or reading at night, so
accessibility is treated as a core requirement, not a polish pass.

- **Contrast.** Every text color meets WCAG 2.2 AA (at least 4.5:1) against
  both surfaces it sits on, in light and dark mode. The ratios are written next
  to each color in `Theme.swift`. Text on filled buttons switches to black in
  dark mode, where white on the brighter fills would fall below 3:1.
- **Dynamic Type.** All text scales with the system text size, up to the largest
  accessibility size. Rows of metrics, the status line and episode rows switch
  from side by side to stacked at those sizes instead of truncating. The 80pt
  heart-rate reading grows less, so it doesn't push everything else off screen.
- **VoiceOver.** Decorative icons are hidden, so each control reads as one
  clear phrase. Section titles are headers you can jump between with the rotor.
  The 1 to 5 severity rating is a single adjustable control (swipe up or down),
  the selected breathing pace is announced as selected, and chart bars and
  points have spoken values.
- **Reduce Motion.** The beating heart stays still, and the breathing circle
  changes size without the slow grow and shrink. The phase words, countdown and
  haptic tap still pace the breath.
- **Color is never the only signal.** A possible episode is shown in amber
  *and* says "Possible episode" in words.
- **Tap targets** are at least 44pt, Apple's recommended minimum.

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

The Xcode project can be regenerated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen). The committed `SVTMonitor.xcodeproj` is pinned to
`objectVersion = 56` so it opens in Xcode 15.4. If you regenerate with
`xcodegen generate`, re-apply that pin:

```bash
sed -i '' 's/objectVersion = 77;/objectVersion = 56;/' \
  SVTMonitor.xcodeproj/project.pbxproj
```

---

## Tests

The test target covers the parts of the app where being wrong actually matters:

| Suite | Covers |
| 