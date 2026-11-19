import SwiftUI
import SwiftData

/// Manual episode entry.
///
/// Most episodes do not happen while you are wearing a watch with the app
/// open. Being able to write one down afterwards — even roughly — is what
/// makes the history worth showing a cardiologist, so manual entries are
/// stored as first-class episodes and simply flagged with `isManualEntry`.
struct LogEpisodeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var startDate = Date()
    @State private var durationMinutes = 2
    @State private var durationSeconds = 0
    @State private var peakBPMText = ""
    @State private var knowsPeak = false
    @State private var symptoms: Set<Symptom> = []
    @State private var triggers: Set<EpisodeTrigger> = []
    @State private var severity = 0
    @State private var notes = ""

    private var duration: TimeInterval {
        TimeInterval(durationMinutes * 60 + durationSeconds)
    }

    /// Anything outside this can't be a real heart rate, so it's almost
    /// certainly a typo (an extra zero) rather than data worth keeping.
    static let plausibleBPM: ClosedRange<Double> = 30...300

    private var peakBPM: Double? {
        guard knowsPeak, let value = Double(peakBPMText), Self.plausibleBPM.contains(value) else { return nil }
        return value
    }

    private var peakIsInvalid: Bool { knowsPeak && !peakBPMText.isEmpty && peakBPM == nil }

    private var canSave: Bool { duration > 0 && !peakIsInvalid }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    whenCard
                    howLongCard
                    rateCard
                    symptomsCard
                    triggersCard
                    severityCard
                    notesCard
                }
                .padding(20)
            }
            .appBackground()
            .navigationTitle("Log an episode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(Theme.font(17, .semibold))
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: Sections

    private var whenCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "When did it start")
                DatePicker(
                    "Start",
                    selection: $startDate,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }
        }
    }

    private var howLongCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "How long did it last")
                HStack(spacing: 16) {
                    Picker("Minutes", selection: $durationMinutes) {
                        ForEach(0..<121, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 110)
                    .clipped()

                    Picker("Seconds", selection: $durationSeconds) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) sec").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 110)
                    .clipped()
                }
                if duration == 0 {
                    Text("Give it at least a few seconds so it can be saved.")
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.alert)
                }
            }
        }
    }

    private var rateCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Heart rate")
                Toggle(isOn: $knowsPeak) {
                    Text("I know roughly how high it got")
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.accent)

                if knowsPeak {
                    HStack(spacing: 10) {
                        TextField("e.g. 180", text: $peakBPMText)
                            .keyboardType(.numberPad)
                            .accessibilityLabel("Peak heart rate, beats per minute")
                            .font(Theme.font(20, .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.background)
                            )
                        Text("bpm")
                            .font(Theme.font(16, .semibold))
                            .foregroundStyle(Theme.inkSecondary)
                            .accessibilityHidden(true)
                    }
                    if peakIsInvalid {
                        Text("Enter a number between \(Int(Self.plausibleBPM.lowerBound)) and \(Int(Self.plausibleBPM.upperBound)).")
                            .font(Theme.font(13))
                            .foregroundStyle(Theme.alert)
                    }
                } else {
                    Text("That's fine — leave it off and the episode is still recorded.")
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
    }

    private var symptomsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "What did you feel")
                SymptomPicker(selection: $symptoms)
            }
        }
    }

    private var triggersCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Anything before it started")
                TriggerPicker(selection: $triggers)
            }
        }
    }

    private var severityCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "How rough was it")
                SeverityPicker(severity: $severity)
            }
        }
    }

    private var notesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Notes")
                TextEditor(text: $notes)
                    .font(Theme.font(15))
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.background)
                    )
            }
        }
    }

    // MARK: Save

    private func save() {
        let peak = peakBPM ?? 0
        let episode = SVTEpisode(
            startDate: startDate,
            endDate: startDate.addingTimeInterval(duration),
            peakBPM: peak,
            // There's no trace for a hand-logged episode, so there is no real
            // average. Zero means "unknown" and is hidden in the UI.
            avgBPM: 0,
            sampleCount: 0,
            hrTrace: [],
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            symptoms: Array(symptoms),
            triggers: Array(triggers),
            perceivedSeverity: severity,
            isManualEntry: true
        )
        context.insert(episode)
        try? context.save()
        dismiss()
    }
}

#Preview {
    LogEpisodeView()
        .modelContainer(PreviewData.container)
}
