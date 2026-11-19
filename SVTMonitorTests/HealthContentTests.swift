import XCTest
@testable import SVTMonitor

/// Guards the health guidance against drifting from its sources.
///
/// These are the strings someone reads mid-episode, so a well-meaning edit
/// that changes a timing or drops a warning should fail loudly here rather
/// than ship.
final class HealthContentTests: XCTestCase {

    // MARK: Maneuvers

    /// REVERT (Lancet 2015): 15 s strain, 15 s flat with legs raised, then
    /// 45 s semi-reclined.
    func testModifiedValsalvaMatchesREVERTTimings() {
        let steps = VagalManeuver.modifiedValsalva.steps
        XCTAssertEqual(steps.count, 4)
        XCTAssertTrue(steps[1].contains("15 seconds"), "strain should last 15 seconds")
        XCTAssertTrue(steps[2].contains("legs"), "third step raises the legs")
        XCTAssertTrue(steps[2].contains("15 seconds"), "legs stay raised for 15 seconds")
        XCTAssertTrue(steps[3].contains("45 seconds"), "then 45 seconds semi-reclined")
    }

    func testEveryManeuverStartsSeatedOrLying() {
        for maneuver in VagalManeuver.all {
            let first = maneuver.steps.first?.lowercased() ?? ""
            XCTAssertTrue(first.contains("sit") || first.contains("lie"),
                          "\(maneuver.title) should start by sitting or lying down")
        }
    }

    func testCarotidMassageWarningIsPresent() {
        XCTAssertTrue(VagalManeuver.neverDoAlone.lowercased().contains("carotid"))
    }

    /// NHS: call emergency services for chest pain, breathlessness, feeling
    /// faint, or an episode longer than usual; don't drive yourself.
    func testSeekHelpCoversNHSCriteria() {
        let points = VagalManeuver.seekHelpPoints.joined(separator: " ").lowercased()
        for phrase in ["chest pain", "faint", "shortness of breath", "longer than your usual"] {
            XCTAssertTrue(points.contains(phrase), "missing: \(phrase)")
        }
        XCTAssertTrue(VagalManeuver.seekHelpFooter.lowercased().contains("do not drive yourself"))
    }

    // MARK: Breathing

    /// The default pace is 4 in, 6 out: a 10 s cycle, six breaths a minute.
    func testDefaultBreathingPatternIsSixBreathsPerMinute() throws {
        let first = try XCTUnwrap(BreathingPattern.all.first)
        XCTAssertEqual(first.id, BreathingPattern.extendedExhale.id)
        XCTAssertEqual(60 / first.cycleDuration, 6, accuracy: 0.001)
    }

    // MARK: Sources

    func testSourcesAreHTTPSAndUnique() {
        let sources = HealthSource.all
        XCTAssertFalse(sources.isEmpty)
        XCTAssertEqual(Set(sources.map(\.id)).count, sources.count)
        for source in sources {
            XCTAssertEqual(source.url.scheme, "https", source.title)
            XCTAssertFalse(source.usedFor.isEmpty, source.title)
        }
    }

    // MARK: Manual logging

    func testPlausibleHeartRateRangeRejectsTypos() {
        let range = LogEpisodeView.plausibleBPM
        XCTAssertTrue(range.contains(180))
        XCTAssertFalse(range.contains(1800), "an extra zero should be rejected")
        XCTAssertFalse(range.contains(0))
    }
}
