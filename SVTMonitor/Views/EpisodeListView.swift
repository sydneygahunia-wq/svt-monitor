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
                        Label("Log episode", systemImage: "plus.circle.fill")
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
        ScrollView {
            LazyVStack(spacing: 12) {
                summaryHeader
                ForEach(episodes) { episode in
                    NavigationLink {
                        EpisodeDetailView(episode: episode)
                    } label: {
                        EpisodeRow(episode: episode)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            delete(episode)
                        } label: {
                            Label("Delete episode", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
    }

    private var summaryHeader: some View {
        HStack(spacing: 12) {
            summaryTile(value: "\(episodes.count)", label: "Recorded")
            summaryTile(value: "\(Int(episodes.map(\.peakBPM).max() ?? 0))", label: "Highest peak")
        }
        .padding(.bottom, 4)
    }

    private func summaryTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.rounded(26, .bold))
                .foregroundStyle(Theme.ink)
            Text(label.uppercased())
                .font(Theme.rounded(11, .semibold))
                .tracking(0.5)
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Theme.cardShadow, radius: 10, y: 4)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.blue)
            Text("No episodes recorded")
                .font(Theme.rounded(22, .bold))
                .foregroundStyle(Theme.ink)
            Text("That's a good thing. Detected episodes appear here — and if one happens while you aren't wearing your watch, you can write it down yourself.")
                .font(Theme.rounded(15))
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

/// One row in the episode list.
private struct EpisodeRow: View {
    let episode: SVTEpisode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if !tagTitles.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(episode.symptoms) { symptom in
                        TagChip(title: symptom.title, systemImage: symptom.systemImage, tint: Theme.peachDeep)
                    }
                    ForEach(episode.triggers) { trigger in
                        TagChip(title: trigger.title, systemImage: trigger.systemImage)
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Theme.cardShadow, radius: 10, y: 4)
    }

    private var tagTitles: [String] {
        episode.symptoms.map(\.title) + episode.triggers.map(\.title)
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.peach.opacity(0.25))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.peachDeep)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(episode.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.rounded(16, .semibold))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .semibold))
                    Text(episode.durationText)
                        .font(Theme.rounded(13, .medium))
                    if episode.isManualEntry {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    if episode.isOngoing {
                        Text("• ongoing")
                            .font(Theme.rounded(13, .semibold))
                            .foregroundStyle(Theme.peachDeep)
                    }
                }
                .foregroundStyle(Theme.inkSecondary)
            }

            Spacer()

            if episode.peakBPM > 0 {
                PeakChip(peakBPM: Int(episode.peakBPM.rounded()))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.hairline)
        }
    }
}

#Preview {
    EpisodeListView()
        .modelContainer(PreviewData.container)
}
