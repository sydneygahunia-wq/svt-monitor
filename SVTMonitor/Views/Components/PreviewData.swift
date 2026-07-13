import Foundation
import SwiftData

/// In-memory SwiftData container + sample objects used only by SwiftUI
/// `#Preview` blocks. Keeps previews self-contained without touching disk.
enum PreviewData {

    /// A memory-only container pre-loaded with the demo seed episodes.
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: SVTEpisode.self, configurations: config)
        let context = ModelContext(container)
        SeedData.seedIfNeeded(context: context)
        return container
    }()

    /// A single detached sample episode for detail previews.
    static var sampleEpisode: SVTEpisode {
        let start = Date().addingTimeInterval(-3600)
        var trace: [Double] = []
        for i in 0..<80 {
            let t = Double(i)
            let value: Double
            if i < 8 { value = 88 + t * 11 }
            else if i < 68 { value = 180 - Double.random(in: 0...10) }
            else { value = 180 - Double(i - 68) * 12 }
            trace.append(max(80, value))
        }
        let avg = trace.reduce(0, +) / Double(trace.count)
        return SVTEpisode(
            startDate: start,
            endDate: start.addingTimeInterval(160),
            peakBPM: trace.max() ?? 182,
            avgBPM: avg,
            sampleCount: trace.count,
            hrTrace: trace,
            notes: "Sample episode for preview."
        )
    }
}
