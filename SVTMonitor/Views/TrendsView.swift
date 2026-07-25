import SwiftUI
import SwiftData
import Charts

/// Longer-term patterns: how many episodes occur per week, and how peak heart
/// rate has trended over time, across a selectable date range.
struct TrendsView: View {
    @Query(sort: \SVTEpisode.startDate, order: .forward) private var episodes: [SVTEpisode]

    enum Range: String, CaseIterable, Identifiable {
        case thirty = "30 days"
        case ninety = "90 days"
        case all = "All time"
        var id: String { rawValue }
        var days: Int? {
            switch self {
            case .thirty: return 30
            case .ninety: return 90
            case .all: return nil
            }
        }
    }

    @State private var range: Range = .ninety
    @State private var isSharingSummary = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    picker
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        overviewCard
                        patternsCard
                        weeklyCard
                        peakCard
                        shareCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Trends")
            .sheet(isPresented: $isSharingSummary) {
                ShareSheet(text: EpisodeInsights.appointmentSummary(
                    for: filtered,
                    rangeDescription: range.rawValue
                ))
            }
        }
    }

    // MARK: Patterns

    private var insights: EpisodeInsights.Summary { EpisodeInsights.summarize(filtered) }

    /// Symptom and trigger frequencies.
    ///
    /// This is deliberately framed as "what you reported most", not "what
    /// causes your episodes". The app counts; the cardiologist interprets.
    private var patternsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Patterns")

                if insights.taggedCount == 0 {
                    Text("Tag symptoms and possible triggers on an episode and they'll be counted here.")
                        .font(Theme.rounded(14))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    if !insights.topSymptoms.isEmpty {
                        tagBreakdown(
                            title: "Most reported symptoms",
                            rows: insights.topSymptoms.prefix(4).map {
                                ($0.tag.title, $0.tag.systemImage, $0.count, $0.share)
                            },
                            tint: Theme.peachDeep
                        )
                    }

                    if !insights.topTriggers.isEmpty {
                        tagBreakdown(
                            title: "Most reported possible triggers",
                            rows: insights.topTriggers.prefix(4).map {
                                ($0.tag.title, $0.tag.systemImage, $0.count, $0.share)
                            },
                            tint: Theme.blueDeep
                        )
                    }

                    Text("These are counts of what you tagged, not causes. Worth raising with your care team, not acting on alone.")
                        .font(Theme.rounded(12))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func tagBreakdown(
        title: String,
        rows: [(String, String, Int, Double)],
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.rounded(14, .semibold))
                .foregroundStyle(Theme.ink)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    Image(systemName: row.1)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 20)

                    Text(row.0)
                        .font(Theme.rounded(14))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 130, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.background)
                            Capsule()
                                .fill(tint.opacity(0.75))
                                .frame(width: max(6, geo.size.width * row.3))
                        }
                    }
                    .frame(height: 10)

                    Text("\(row.2)")
                        .font(Theme.rounded(13, .semibold))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
    }

    // MARK: Share

    private var shareCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "For your appointment")
                Text("Export a plain summary of this range — counts, durations, peaks and what you tagged — to hand to your cardiologist.")
                    .font(Theme.rounded(14))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    isSharingSummary = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share summary")
                            .font(Theme.rounded(15, .semibold))
                    }
                    .foregroundStyle(Theme.blueDeep)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Theme.blue.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Data

    private var filtered: [SVTEpisode] {
        guard let days = range.days else { return episodes }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return episodes.filter { $0.startDate >= cutoff }
    }

    private struct WeekBucket: Identifiable {
        let id = UUID()
        let weekStart: Date
        let count: Int
    }

    private var weeklyBuckets: [WeekBucket] {
        let cal = Calendar.current
        var counts: [Date: Int] = [:]
        for episode in filtered {
            if let week = cal.dateInterval(of: .weekOfYear, for: episode.startDate)?.start {
                counts[week, default: 0] += 1
            }
        }
        return counts
            .map { WeekBucket(weekStart: $0.key, count: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    // MARK: Views

    private var picker: some View {
        Picker("Range", selection: $range) {
            ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var overviewCard: some View {
        Card {
            HStack(spacing: 12) {
                MetricView(value: "\(filtered.count)", label: "Episodes", tint: Theme.ink, alignment: .center)
                MetricView(value: "\(Int(filtered.map(\.peakBPM).max() ?? 0))", label: "Peak BPM", tint: Theme.peachDeep, alignment: .center)
                MetricView(value: avgDurationText, label: "Avg length", tint: Theme.blueDeep, alignment: .center)
            }
        }
    }

    private var avgDurationText: String {
        guard !filtered.isEmpty else { return "--" }
        let avg = filtered.map(\.duration).reduce(0, +) / Double(filtered.count)
        return SVTEpisode.format(duration: avg)
    }

    private var weeklyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Episodes per week")
                Chart(weeklyBuckets) { bucket in
                    BarMark(
                        x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                        y: .value("Episodes", bucket.count),
                        width: .fixed(18)
                    )
                    .cornerRadius(6)
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.blue, Theme.blueDeep],
                                       startPoint: .top, endPoint: .bottom)
                    )
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 180)
            }
        }
    }

    private var peakCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Peak BPM over time")
                Chart(filtered) { episode in
                    PointMark(
                        x: .value("Date", episode.startDate),
                        y: .value("Peak BPM", episode.peakBPM)
                    )
                    .foregroundStyle(Theme.peachDeep)
                    .symbolSize(90)
                }
                .chartYScale(domain: peakDomain)
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
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 180)
            }
        }
    }

    private var peakDomain: ClosedRange<Double> {
        let peaks = filtered.map(\.peakBPM)
        let lo = (peaks.min() ?? 140) - 15
        let hi = (peaks.max() ?? 200) + 15
        return lo...hi
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 46))
                .foregroundStyle(Theme.blue)
            Text("No episodes in this range")
                .font(Theme.rounded(19, .bold))
                .foregroundStyle(Theme.ink)
            Text("Trends will appear once episodes are recorded in the selected window.")
                .font(Theme.rounded(14))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    TrendsView()
        .modelContainer(PreviewData.container)
}
