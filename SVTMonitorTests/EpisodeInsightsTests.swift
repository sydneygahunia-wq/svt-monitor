import XCTest
@testable import SVTMonitor

/// Tests for the descriptive statistics behind the Trends screen.
///
/// These matter because the numbers may end up being read out at a cardiology
/// appointment. A miscounted trigger is not a cosmetic bug.
final class EpisodeInsightsTests: XCTestCase {

    // MARK: Helpers

    private func makeEpisode(
        daysAgo: Double = 1,
        duration: TimeInterval = 120,
        peak: Double = 175,
        symptoms: [Symptom] = [],
        triggers: [EpisodeTrigger] = [],
        severity: Int = 0,
        manual: Bool = false
    ) -> SVTEpisode {
        let start = Date().addingTimeInterval(-daysAgo * 86_400)
        return SVTEpisode(
            startDate: start,
            endDate: start.addingTimeInterval(duration),
            peakBPM: peak,
            avgBPM: peak - 10,
            sampleCount: 60,
            hrTrace: [],
            notes: "",
            symptoms: symptoms,
            triggers: triggers,
            perceivedSeverity: severity,
            isManualEntry: manual
        )
    }

    // MARK: Summary

    func testEmptyInputProducesEmptySummary() {
        XCTAssertEqual(EpisodeInsights.summarize([]), .empty)
    }

    func testAveragesAndExtremes() {
        let episodes = [
            makeEpisode(duration: 60, peak: 160),
            makeEpisode(duration: 120, peak: 180),
            makeEpisode(duration: 240, peak: 200)
        ]
        let summary = EpisodeInsights.summarize(episodes)

        XCTAssertEqual(summary.episodeCount, 3)
        XCTAssertEqual(summary.averageDuration, 140, accuracy: 1)
        XCTAssertEqual(summary.longestDuration, 240, accuracy: 1)
        XCTAssertEqual(summary.averagePeakBPM, 180, accuracy: 0.001)
        XCTAssertEqual(summary.highestPeakBPM, 200, accuracy: 0.001)
    }

    func testUnratedEpisodesAreExcludedFromAverageSeverity() {
        let episodes = [
            makeEpisode(severity: 4),
            makeEpisode(severity: 2),
            makeEpisode(severity: 0)   // not rated — must not drag the mean down
        ]
        let summary = EpisodeInsights.summarize(episodes)
        XCTAssertEqual(try XCTUnwrap(summary.averageSeverity), 3, accuracy: 0.001)
    }

    func testAverageSeverityIsNilWhenNothingIsRated() {
        let summary = EpisodeInsights.summarize([makeEpisode(), makeEpisode()])
        XCTAssertNil(summary.averageSeverity)
    }

    // MARK: Tag ranking

    func testSymptomsAreRankedByFrequency() {
        let episodes = [
            makeEpisode(symptoms: [.palpitations, .anxiety]),
            makeEpisode(symptoms: [.palpitations, .lightheaded]),
            makeEpisode(symptoms: [.palpitations])
        ]
        let ranked = EpisodeInsights.summarize(episodes).topSymptoms

        XCTAssertEqual(ranked.first?.tag, .palpitations)
        XCTAssertEqual(ranked.first?.count, 3)
        XCTAssertEqual(try XCTUnwrap(ranked.first?.share), 1.0, accuracy: 0.001)
    }

    func testTiedCountsAreOrderedStably() {
        let episodes = [
            makeEpisode(triggers: [.stress]),
            makeEpisode(triggers: [.caffeine])
        ]
        let ranked = EpisodeInsights.summarize(episodes).topTriggers
        // Equal counts fall back to raw-value order, so the list never shuffles
        // between renders.
        XCTAssertEqual(ranked.map(\.tag), [.caffeine, .stress])
    }

    func testDuplicateTagsWithinOneEpisodeCountOnce() {
        // The pickers use a Set, but the stored raw array could contain a
        // duplicate from older data. One episode must never count twice.
        let episode = makeEpisode()
        episode.symptomsRaw = ["palpitations", "palpitations", "anxiety"]

        let ranked = EpisodeInsights.summarize([episode]).topSymptoms
        XCTAssertEqual(ranked.first(where: { $0.tag == .palpitations })?.count, 1)
    }

    func testUnknownRawTagsAreIgnoredRatherThanCrashing() {
        let episode = makeEpisode()
        episode.symptomsRaw = ["palpitations", "not-a-real-symptom"]

        XCTAssertEqual(episode.symptoms, [.palpitations])
        let ranked = EpisodeInsights.summarize([episode]).topSymptoms
        XCTAssertEqual(ranked.count, 1)
    }

    func testShareIsRelativeToTaggedEpisodesOnly() {
        let episodes = [
            makeEpisode(symptoms: [.palpitations]),
            makeEpisode(symptoms: [.palpitations]),
            makeEpisode()   // untagged — shouldn't dilute the share
        ]
        let ranked = EpisodeInsights.summarize(episodes).topSymptoms
        XCTAssertEqual(try XCTUnwrap(ranked.first?.share), 1.0, accuracy: 0.001)
    }

    func testTaggedCountCountsEitherKindOfTag() {
        let episodes = [
            makeEpisode(symptoms: [.nausea]),
            makeEpisode(triggers: [.alcohol]),
            makeEpisode()
        ]
        XCTAssertEqual(EpisodeInsights.summarize(episodes).taggedCount, 2)
    }

    // MARK: Weekly grouping

    func testPerWeekGroupsAndSortsOldestFirst() {
        let episodes = [
            makeEpisode(daysAgo: 1),
            makeEpisode(daysAgo: 2),
            makeEpisode(daysAgo: 20)
        ]
        let weeks = EpisodeInsights.perWeek(episodes)

        XCTAssertEqual(weeks.map(\.count).reduce(0, +), 3)
        XCTAssertTrue(zip(weeks, weeks.dropFirst()).allSatisfy { $0.weekStart < $1.weekStart })
    }

    // MARK: Appointment summary

    func testAppointmentSummaryHandlesNoEpisodes() {
        let text = EpisodeInsights.appointmentSummary(for: [], rangeDescription: "30 days")
        XCTAssertTrue(text.contains("No episodes recorded"))
    }

    func testAppointmentSummaryIncludesCountsAndTags() {
        let episodes = [
            makeEpisode(symptoms: [.palpitations], triggers: [.caffeine], severity: 3),
            makeEpisode(symptoms: [.palpitations], manual: true)
        ]
        let text = EpisodeInsights.appointmentSummary(for: episodes, rangeDescription: "90 days")

        XCTAssertTrue(text.contains("Episodes recorded: 2"))
        XCTAssertTrue(text.contains("Palpitations"))
        XCTAssertTrue(text.contains("Caffeine"))
        XCTAssertTrue(text.contains("logged manually"))
        XCTAssertTrue(text.contains("Not a medical device"))
    }
}
