import SwiftUI
import SwiftData

/// A newest-first list of recorded episodes, each summarised by date, duration
/// and peak BPM. Swipe to delete; tap to see the full detail.
struct EpisodeListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SVTEpisode.startDate, order: .reverse) private var episodes: [SVTEpisode]

    private enum Sheet: String, Identifiable {
        case log
        case share
        var id: String { rawValue }
    }

    @State private var sheet: Sheet?

    var body: some View {
        NavigationStack {
            Group {
                if episodes.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .appBackground()
            .navigationTitle("Episodes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !episodes.isEmpty {
                        Button {
                            sheet = .share
                        } label: {
                            Label("Share summary", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        sheet = .log
                    } label: {
                        Label("Log episode", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $sheet) { which in
                switch which {
                case .log:
                    LogEpisodeView()
                case .share:
                    ShareSheet(text: EpisodeInsights.appointmentSummary(
                        for: episodes,
                        rangeDescription: "All recorded episodes"
                    ))
                }
            }
        }
    }

    private var list: some View {
        List {
            Section {
            } header: {
                summaryHeader
            }
            ForEach(groupedByMonth, id: \.month) { group in
                Section {
                    ForEach(group.episodes) { episode in
                        NavigationLink {
                            EpisodeDetailView(episode: episode)
                        } label: {
                            EpisodeRow(episode: episode)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { group.episodes[$0] }.forEach(delete)
                    }
                } header: {
                    Text(group.month.formatted(.dateTime.month(.wide).year()))
                        .font(Theme.font(20, .bold))
                        .foregroundStyle(Theme.ink)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// Sections like Health's history lists: one per month, newest first.
    private var groupedByMonth: [(month: Date, episodes: [SVTEpisode])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: episodes) { episode in
            calendar.dateInterval(of: .month, for: episode.startDate)?.start ?? episode.startDate
        }
        return groups
            .map { (month: $0.key, episodes: $0.value) }
            .sorted { $0.month > $1.month }
    }

    /// One plain sentence instead of stat tiles.
    private var summaryHeader: some View {
        let count = episodes.count
        let peak = Int(episodes.map(\.peakBPM).max() ?? 0)
        return Text("\(count) episode\(count == 1 ? "" : "s") recorded\(peak > 0 ? ", highest \(peak) bpm" : "")")
            .font(Theme.font(15))
            .foregroundStyle(Theme.inkSecondary)
            .textCase(nil)
            .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.inkSecondary)
                .accessibilityHidden(true)
            Text("No episodes recorded")
                .font(Theme.font(22, .bold))
                .foregroundStyle(Theme.ink)
            Text("That's a good thing. Detected episodes appear here — and if one happens while you aren't wearing your watch, you can write it down yourself.")
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                sheet = .log
            } label: {
                PrimaryButtonLabel(title: "Log an episode", systemImage: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func delete(_ episode: SVTEpisode) {
        context.delete(episode)
        try? context.save()
    }
}

/// One row in the episode list: when, how long, how fast. Tags are a quiet
/// line of text rather than chips, so a long history stays scannable.
private struct EpisodeRow: View {
    let episode: SVTEpisode
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At accessibility text sizes the peak moves under the date instead of
        // squeezing it into a sliver.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            VStack(alignment: .leading, spacing: 3) {
                Text(episode.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(Theme.font(17, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(metaLine)
                    .font(Theme.font(15))
                    .foregroundStyle(episode.isOngoing ? Theme.alert : Theme.inkSecondary)
                if !tagTitles.isEmpty {
                    Text(tagTitles.joined(separator: ", "))
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                }
            }

            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }

            if episode.peakBPM > 0 {
                PeakChip(peakBPM: Int(episode.peakBPM.rounded()))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var metaLine: String {
        var parts = [episode.startDate.formatted(date: .omitted, time: .shortened), episode.durationText]
        if episode.isManualEntry { parts.append("logged by hand") }
        if episode.isOngoing { parts.append("ongoing") }
        return parts.joined(separator: " · ")
    }

    private var tagTitles: [String] {
        episode.symptoms.map(\.title) + episode.triggers.map(\.title)
    }
}

#Preview {
    EpisodeListView()
        .modelContainer(PreviewData.container)
}
