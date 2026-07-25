import SwiftUI
import SwiftData
import Charts

/// Full detail for one episode: headline stats, the recorded heart-rate trace
/// with the detection threshold overlaid, and editable patient notes.
struct EpisodeDetailView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: AppSettings
    @Bindable var episode: SVTEpisode

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statsCard
                if episode.hasRedFlagSymptom { redFlagCard }
                traceCard
                symptomsCard
                triggersCard
                severityCard
                notesCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("Episode")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Stats

    private var statsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.peachDeep)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(episode.startDate.formatted(date: .complete, time: .omitted))
                            .font(Theme.rounded(15, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Started \(episode.startDate.formatted(date: .omitted, time: .shortened))")
                            .font(Theme.rounded(13))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }

                Divider().background(Theme.hairline)

                HStack(spacing: 12) {
                    MetricView(value: episode.durationText, label: "Duration", tint: Theme.ink, alignment: .center)
                    MetricView(value: "\(Int(episode.peakBPM.rounded()))", label: "Peak BPM", tint: Theme.peachDeep, alignment: .center)
                    MetricView(value: "\(Int(episode.avgBPM.rounded()))", label: "Avg BPM", tint: Theme.blueDeep, alignment: .center)
                }

                if episode.isManualEntry || episode.usedCalmMode || episode.severityText != nil {
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        if let severity = episode.severityText {
                            TagChip(title: severity, systemImage: "gauge.medium", tint: Theme.peachDeep)
                        }
                        if episode.isManualEntry {
                            TagChip(title: "Logged by hand", systemImage: "square.and.pencil", tint: Theme.inkSecondary)
                        }
                        if episode.usedCalmMode {
                            TagChip(title: "Used calm mode", systemImage: "wind", tint: Theme.blueDeep)
                        }
                    }
                }
            }
        }
    }

    // MARK: Red flag notice

    /// Shown when a tagged symptom is one that warrants urgent review. It is
    /// intentionally not a diagnosis — it points at the care team, not at a
    /// conclusion.
    private var redFlagCard: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.peachDeep)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Worth telling your care team")
                        .font(Theme.rounded(16, .bold))
                        .foregroundStyle(Theme.ink)
                    Text("You tagged chest pain or nearly fainting during this episode. Those are worth raising with your cardiologist, and worth calling emergency services for if they happen again.")
                        .font(Theme.rounded(14))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Tags

    private var symptomSelection: Binding<Set<Symptom>> {
        Binding(
            get: { Set(episode.symptoms) },
            set: { newValue in
                episode.symptoms = Array(newValue)
                try? context.save()
            }
        )
    }

    private var triggerSelection: Binding<Set<EpisodeTrigger>> {
        Binding(
            get: { Set(episode.triggers) },
            set: { newValue in
                episode.triggers = Array(newValue)
                try? context.save()
            }
        )
    }

    private var severityBinding: Binding<Int> {
        Binding(
            get: { episode.perceivedSeverity },
            set: { newValue in
                episode.perceivedSeverity = newValue
                try? context.save()
            }
        )
    }

    private var symptomsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "What you felt")
                SymptomPicker(selection: symptomSelection)
                if episode.symptoms.isEmpty {
                    Text("Tagging symptoms takes a second now and saves you trying to remember at your next appointment.")
                        .font(Theme.rounded(13))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var triggersCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Possible triggers")
                TriggerPicker(selection: triggerSelection)
                Text("One episode after coffee means nothing. A pattern across many is worth showing someone.")
                    .font(Theme.rounded(13))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var severityCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "How rough it felt")
                SeverityPicker(severity: severityBinding)
            }
        }
    }

    // MARK: Trace chart

    private struct TracePointIndexed: Identifiable {
        let id = UUID()
        let index: Int
        let bpm: Double
    }

    private var indexedTrace: [TracePointIndexed] {
        episode.hrTrace.enumerated().map { TracePointIndexed(index: $0.offset, bpm: $0.element) }
    }

    private var traceCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Heart rate during episode")

                if episode.hrTrace.isEmpty {
                    Text("No trace was recorded for this episode.")
                        .font(Theme.rounded(14))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                } else {
                    chart
                    HStack {
                        Text(episode.startDate.formatted(date: .omitted, time: .shortened))
                        Spacer()
                        Text((episode.endDate ?? Date()).formatted(date: .omitted, time: .shortened))
                    }
                    .font(Theme.rounded(11, .medium))
                    .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(indexedTrace) { point in
                LineMark(
                    x: .value("Sample", point.index),
                    y: .value("BPM", point.bpm)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.peachDeep)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                AreaMark(
                    x: .value("Sample", point.index),
                    y: .value("BPM", point.bpm)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(colors: [Theme.peach.opacity(0.4), .clear],
                                   startPoint: .top, endPoint: .bottom)
                )
            }

            RuleMark(y: .value("Threshold", settings.threshold))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(Theme.blueDeep.opacity(0.8))
                .annotation(position: .top, alignment: .leading) {
                    Text("Threshold \(Int(settings.threshold))")
                        .font(Theme.rounded(10, .semibold))
                        .foregroundStyle(Theme.blueDeep)
                }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))")
                            .font(Theme.rounded(10))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
        }
        .frame(height: 200)
    }

    private var yDomain: ClosedRange<Double> {
        let bpms = episode.hrTrace
        let lo = min((bpms.min() ?? 70) - 10, settings.threshold - 10)
        let hi = max((bpms.max() ?? 190) + 10, settings.threshold + 10)
        return lo...hi
    }

    // MARK: Notes

    private var notesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Notes")
                TextField(
                    "Add how you felt, what you were doing, anything you'd tell your care team…",
                    text: $episode.notes,
                    axis: .vertical
                )
                .font(Theme.rounded(15))
                .foregroundStyle(Theme.ink)
                .lineLimit(3...8)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.background)
                )
                .onChange(of: episode.notes) { _, _ in
                    try? context.save()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EpisodeDetailView(episode: PreviewData.sampleEpisode)
            .environmentObject(AppSettings())
    }
}
