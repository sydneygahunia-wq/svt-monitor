import XCTest
@testable import SVTMonitor

/// Tests for the tag storage on `SVTEpisode`.
///
/// Tags round-trip through `[String]` so SwiftData can persist them, and that
/// conversion is exactly the sort of quiet code that breaks without notice.
final class SVTEpisodeTaggingTests: XCTestCase {

    private func makeEpisode() -> SVTEpisode {
        SVTEpisode(startDate: Date(), peakBPM: 180, avgBPM: 170, sampleCount: 10)
    }

    func testSymptomsRoundTripThroughRawStorage() {
        let episode = makeEpisode()
        episode.symptoms = [.palpitations, .nausea]

        XCTAssertEqual(Set(episode.symptomsRaw), ["palpitations", "nausea"])
        XCTAssertEqual(Set(episode.symptoms), [.palpitations, .nausea])
    }

    func testTriggersRoundTripThroughRawStorage() {
        let episode = makeEpisode()
        episode.triggers = [.caffeine, .poorSleep]

        XCTAssertEqual(Set(episode.triggersRaw), ["caffeine", "poorSleep"])
        XCTAssertEqual(Set(episode.triggers), [.caffeine, .poorSleep])
    }

    func testUnrecognisedRawValuesAreDropped() {
        let episode = makeEpisode()
        episode.triggersRaw = ["caffeine", "moon-phase"]
        XCTAssertEqual(episode.triggers, [.caffeine])
    }

    func testDefaultsAreEmptyAndUnflagged() {
        let episode = makeEpisode()
        XCTAssertTrue(episode.symptoms.isEmpty)
        XCTAssertTrue(episode.triggers.isEmpty)
        XCTAssertEqual(episode.perceivedSeverity, 0)
        XCTAssertFalse(episode.isManualEntry)
        XCTAssertFalse(episode.usedCalmMode)
        XCTAssertNil(episode.severityText)
    }

    func testRedFlagDetection() {
        let episode = makeEpisode()
        episode.symptoms = [.palpitations, .fatigue]
        XCTAssertFalse(episode.hasRedFlagSymptom)

        episode.symptoms = [.palpitations, .chestPain]
        XCTAssertTrue(episode.hasRedFlagSymptom)

        episode.symptoms = [.nearFainting]
        XCTAssertTrue(episode.hasRedFlagSymptom)
    }

    func testSeverityLabels() {
        XCTAssertNil(SVTEpisode.severityLabel(0))
        XCTAssertNil(SVTEpisode.severityLabel(6))
        XCTAssertEqual(SVTEpisode.severityLabel(1), "Barely noticed")
        XCTAssertEqual(SVTEpisode.severityLabel(5), "Frightening")
    }

    func testEverySymptomAndTriggerHasDisplayText() {
        for symptom in Symptom.allCases {
            XCTAssertFalse(symptom.title.isEmpty)
            XCTAssertFalse(symptom.systemImage.isEmpty)
        }
        for trigger in EpisodeTrigger.allCases {
            XCTAssertFalse(trigger.title.isEmpty)
            XCTAssertFalse(trigger.systemImage.isEmpty)
        }
    }
}
