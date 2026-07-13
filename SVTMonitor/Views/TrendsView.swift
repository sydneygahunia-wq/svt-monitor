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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    picker
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        overviewCard
                        weeklyCard
                        peakCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle("Trends")
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
