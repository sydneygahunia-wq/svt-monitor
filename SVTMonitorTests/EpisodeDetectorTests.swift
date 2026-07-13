import XCTest
@testable import SVTMonitor

/// Unit tests for the pure detection state machine: onset rule, sustained
/// entry, hysteresis exit, peak/average correctness and robustness to
/// duplicate / out-of-order samples.
final class EpisodeDetectorTests: XCTestCase {

    private let base = Date(timeIntervalSinceReferenceDate: 0)

    /// Build a sample `offset` seconds after the base date.
    private func sample(_ bpm: Double, at offset: TimeInterval) -> HeartRateSample {
        HeartRateSample(bpm: bpm, date: base.addingTimeInterval(offset), source: .simulated)
    }

    // MARK: Sustained entry

    func testSustainedTachycardiaStartsEpisodeOnThirdSample() {
        let detector = EpisodeDetector()

        XCTAssertNil(detector.process(sample(151, at: 0)))
        XCTAssertNil(detector.process(sample(152, at: 2)))
        XCTAssertFalse(detector.isInEpisode)

        let event = detector.process(sample(153, at: 4))
        guard case .started(let summary)? = event else {
            return XCTFail("Expected .started on the third high sample, got \(String(describing: event))")
        }
        XCTAssertTrue(detector.isInEpisode)
        // Episode should start at the first of the qualifying run.
        XCTAssertEqual(summary.startDate, base)
        XCTAssertEqual(summary.sampleCount, 3)
    }

    func testBelowThresholdResetsTheRun() {
        let detector = EpisodeDetector()
        detector.process(sample(151, at: 0))
        detector.process(sample(152, at: 2))
        detector.process(sample(100, at: 4)) // resets the consecutive run
        detector.process(sample(151, at: 6))
        detector.process(sample(152, at: 8))
        XCTAssertFalse(detector.isInEpisode, "Two highs after a reset must not start an episode")

        let event = detector.process(sample(153, at: 10))
        guard case .started? = event else {
            return XCTFail("Expected episode to start after three fresh consecutive highs")
        }
    }

    // MARK: Onset rule

    func testSuddenOnsetStartsEpisodeBeforeThresholdCrossed() {
        let detector = EpisodeDetector()
        XCTAssertNil(detector.process(sample(72, at: 0)))
        XCTAssertNil(detector.process(sample(74, at: 2)))

        // Jump of +71 within the window, above the onset floor (130), but still
        // below the 150 threshold — only the onset rule can catch this.
        let event = detector.process(sample(145, at: 4))
        guard case .started(let summary)? = event else {
            return XCTFail("Expected .started from the onset rule, got \(String(describing: event))")
        }
        XCTAssertTrue(detector.isInEpisode)
        XCTAssertEqual(summary.currentBPM, 145)
    }

    func testGradualRiseDoesNotTriggerOnset() {
        let detector = EpisodeDetector()
        // Climbs 20 BPM per step — no single 40+ jump within the window.
        for (i, bpm) in [90.0, 110, 128, 145].enumerated() {
            detector.process(sample(bpm, at: TimeInterval(i * 2)))
        }
        // None of these crossed 150 and no 40-in-60s jump occurred, so no episode.
        XCTAssertFalse(detector.isInEpisode)
    }

    // MARK: Hysteresis exit

    func testSingleDipDoesNotEndEpisode() {
        let detector = EpisodeDetector()
        startEpisode(detector)

        // One sample in the hysteresis band, then back up — must stay in episode.
        XCTAssertUpdated(detector.process(sample(135, at: 6)))
        XCTAssertUpdated(detector.process(sample(160, at: 8)))
        XCTAssertTrue(detector.isInEpisode)
    }

    func testEpisodeEndsAfterFourConsecutiveLows() {
        let detector = EpisodeDetector()
        startEpisode(detector)

        detector.process(sample(120, at: 6))
        detector.process(sample(118, at: 8))
        detector.process(sample(115, at: 10))
        let event = detector.process(sample(110, at: 12)) // 4th low

        guard case .ended(let episode)? = event else {
            return XCTFail("Expected .ended after four consecutive lows, got \(String(describing: event))")
        }
        XCTAssertFalse(detector.isInEpisode)
        // Episode ends at the moment the rate first dropped.
        XCTAssertEqual(episode.endDate, base.addingTimeInterval(6))
    }

    // MARK: Peak / average correctness

    func testPeakAndAverageComputedOverEpisodeSamples() {
        let detector = EpisodeDetector()
        // Entry run: 150, 160, 170 -> episode starts here.
        detector.process(sample(150, at: 0))
        detector.process(sample(160, at: 2))
        detector.process(sample(170, at: 4))
        // One more elevated sample.
        detector.process(sample(180, at: 6))
        // Four lows to exit (excluded from the stats).
        detector.process(sample(100, at: 8))
        detector.process(sample(100, at: 10))
        detector.process(sample(100, at: 12))
        let event = detector.process(sample(100, at: 14))

        guard case .ended(let episode)? = event else {
            return XCTFail("Expected episode to end")
        }
        XCTAssertEqual(episode.peakBPM, 180)
        XCTAssertEqual(episode.avgBPM, (150 + 160 + 170 + 180) / 4, accuracy: 0.001)
        XCTAssertEqual(episode.sampleCount, 4)
        XCTAssertFalse(episode.hrTrace.isEmpty)
    }

    // MARK: Robustness

    func testOutOfOrderAndDuplicateSamplesAreIgnored() {
        let detector = EpisodeDetector()
        detector.process(sample(150, at: 0))            // valid high #1
        detector.process(sample(160, at: -2))           // out of order -> ignored
        detector.process(sample(170, at: 2))            // valid high #2
        XCTAssertFalse(detector.isInEpisode, "Only two valid highs so far")

        detector.process(sample(999, at: 2))            // duplicate timestamp -> ignored
        XCTAssertFalse(detector.isInEpisode)

        let event = detector.process(sample(175, at: 4)) // valid high #3
        guard case .started? = event else {
            return XCTFail("Third valid high should start the episode")
        }
    }

    func testNonPositiveSamplesAreIgnored() {
        let detector = EpisodeDetector()
        XCTAssertNil(detector.process(sample(0, at: 0)))
        XCTAssertNil(detector.process(sample(-5, at: 2)))
        XCTAssertFalse(detector.isInEpisode)
    }

    // MARK: forceEnd

    func testForceEndFinalizesOngoingEpisode() {
        let detector = EpisodeDetector()
        startEpisode(detector)
        let finished = detector.forceEnd(at: base.addingTimeInterval(6))
        XCTAssertNotNil(finished)
        XCTAssertFalse(detector.isInEpisode)
        XCTAssertNil(detector.forceEnd(at: base.addingTimeInterval(8)), "No episode to end the second time")
    }

    // MARK: Downsampling

    func testDownsampleReducesLargeTraces() {
        let values = (0..<500).map { Double($0) }
        let result = EpisodeDetector.downsample(values, maxPoints: 120)
        XCTAssertLessThanOrEqual(result.count, 120)
        XCTAssertGreaterThan(result.count, 0)
        // Monotonic input stays monotonic after bucket-averaging.
        XCTAssertEqual(result, result.sorted())
    }

    func testDownsampleKeepsSmallTracesUnchanged() {
        let values = [70.0, 150, 180, 90]
        XCTAssertEqual(EpisodeDetector.downsample(values, maxPoints: 120), values)
    }

    // MARK: Helpers

    /// Drives the detector into an active episode via three highs.
    private func startEpisode(_ detector: EpisodeDetector, file: StaticString = #filePath, line: UInt = #line) {
        detector.process(sample(150, at: 0))
        detector.process(sample(155, at: 2))
        detector.process(sample(152, at: 4))
        XCTAssertTrue(detector.isInEpisode, "Setup failed to start an episode", file: file, line: line)
    }

    private func XCTAssertUpdated(_ event: EpisodeDetector.Event?, file: StaticString = #filePath, line: UInt = #line) {
        if case .updated? = event { return }
        XCTFail("Expected .updated, got \(String(describing: event))", file: file, line: line)
    }
}
