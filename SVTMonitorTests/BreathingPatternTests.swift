import XCTest
@testable import SVTMonitor

/// Tests for the paced-breathing clock.
///
/// The pacing has to be exact: if a phase drifts or is skipped, someone
/// following the guide mid-episode ends up holding their breath longer than
/// intended, which is the opposite of helpful.
final class BreathingPatternTests: XCTestCase {

    private let box = BreathingPattern.box  // 4-4-4-4, 16s cycle

    func testCycleDurationSumsSteps() {
        XCTAssertEqual(box.cycleDuration, 16, accuracy: 0.001)
        XCTAssertEqual(BreathingPattern.fourSevenEight.cycleDuration, 19, accuracy: 0.001)
        XCTAssertEqual(BreathingPattern.extendedExhale.cycleDuration, 10, accuracy: 0.001)
    }

    func testRhythmTextSkipsZeroLengthSteps() {
        XCTAssertEqual(box.rhythmText, "4-4-4-4")
        XCTAssertEqual(BreathingPattern.fourSevenEight.rhythmText, "4-7-8")
    }

    func testStartsOnFirstPhase() throws {
        let state = try XCTUnwrap(box.state(at: 0))
        XCTAssertEqual(state.step.phase, .inhale)
        XCTAssertEqual(state.progress, 0, accuracy: 0.001)
        XCTAssertEqual(state.completedCycles, 0)
    }

    func testWalksThroughEveryPhaseInOrder() throws {
        let expected: [(TimeInterval, BreathingPattern.Phase)] = [
            (1,  .inhale),
            (5,  .holdIn),
            (9,  .exhale),
            (13, .holdOut)
        ]
        for (elapsed, phase) in expected {
            let state = try XCTUnwrap(box.state(at: elapsed))
            XCTAssertEqual(state.step.phase, phase, "wrong phase at \(elapsed)s")
        }
    }

    func testWrapsAroundToNextCycle() throws {
        let state = try XCTUnwrap(box.state(at: 17))
        XCTAssertEqual(state.step.phase, .inhale)
        XCTAssertEqual(state.completedCycles, 1)
    }

    func testCountsManyCompletedCycles() throws {
        let state = try XCTUnwrap(box.state(at: 16 * 5 + 2))
        XCTAssertEqual(state.completedCycles, 5)
        XCTAssertEqual(state.step.phase, .inhale)
    }

    func testPhaseBoundaryBelongsToTheNextPhase() throws {
        // At exactly 4s the inhale is finished, so the hold owns that instant.
        let state = try XCTUnwrap(box.state(at: 4))
        XCTAssertEqual(state.step.phase, .holdIn)
        XCTAssertEqual(state.progress, 0, accuracy: 0.001)
    }

    func testCountdownRoundsUpAndNeverShowsZero() throws {
        let start = try XCTUnwrap(box.state(at: 0))
        XCTAssertEqual(start.secondsRemaining, 4)

        let midway = try XCTUnwrap(box.state(at: 1.2))
        XCTAssertEqual(midway.secondsRemaining, 3)

        // Just before the boundary the countdown should still read 1, not 0.
        let almostDone = try XCTUnwrap(box.state(at: 3.99))
        XCTAssertEqual(almostDone.secondsRemaining, 1)
    }

    func testNegativeElapsedIsClampedRatherThanCrashing() throws {
        let state = try XCTUnwrap(box.state(at: -5))
        XCTAssertEqual(state.step.phase, .inhale)
        XCTAssertEqual(state.completedCycles, 0)
    }

    func testProgressStaysWithinBounds() throws {
        for elapsed in stride(from: 0.0, through: 40.0, by: 0.37) {
            let state = try XCTUnwrap(box.state(at: elapsed))
            XCTAssertGreaterThanOrEqual(state.progress, 0)
            XCTAssertLessThanOrEqual(state.progress, 1)
        }
    }

    func testScaleGrowsOnInhaleAndShrinksOnExhale() throws {
        let earlyInhale = try XCTUnwrap(box.state(at: 0.5))
        let lateInhale = try XCTUnwrap(box.state(at: 3.5))
        XCTAssertLessThan(earlyInhale.scale, lateInhale.scale)

        let earlyExhale = try XCTUnwrap(box.state(at: 8.5))
        let lateExhale = try XCTUnwrap(box.state(at: 11.5))
        XCTAssertGreaterThan(earlyExhale.scale, lateExhale.scale)
    }

    func testHoldPhasesKeepConstantScale() throws {
        let holdStart = try XCTUnwrap(box.state(at: 4.1))
        let holdEnd = try XCTUnwrap(box.state(at: 7.9))
        XCTAssertEqual(holdStart.scale, holdEnd.scale, accuracy: 0.001)
    }

    func testPatternWithNoPositiveStepsReturnsNil() {
        let empty = BreathingPattern(id: "empty", name: "", subtitle: "", steps: [])
        XCTAssertNil(empty.state(at: 3))

        let zeroed = BreathingPattern(
            id: "zeroed",
            name: "",
            subtitle: "",
            steps: [BreathingPattern.Step(phase: .inhale, duration: 0)]
        )
        XCTAssertNil(zeroed.state(at: 3))
    }

    func testStepsWithZeroDurationAreSkipped() throws {
        let pattern = BreathingPattern(
            id: "skip",
            name: "",
            subtitle: "",
            steps: [
                BreathingPattern.Step(phase: .inhale, duration: 3),
                BreathingPattern.Step(phase: .holdIn, duration: 0),
                BreathingPattern.Step(phase: .exhale, duration: 3)
            ]
        )
        let state = try XCTUnwrap(pattern.state(at: 4))
        XCTAssertEqual(state.step.phase, .exhale)
        XCTAssertEqual(pattern.cycleDuration, 6, accuracy: 0.001)
    }
}
