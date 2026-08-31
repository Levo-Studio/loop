import Testing
import Foundation

@testable import Loop

// MARK: - Idle timer

@Suite("Idle timer")
struct LoopIdleTimerTests {

    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func decision(_ state: LoopTimerState, after seconds: TimeInterval = 0) -> LoopIdleTimer.Decision {
        LoopIdleTimer.decision(for: state, at: start.addingTimeInterval(seconds))
    }

    // MARK: - Nothing running

    @Test("Fresh timers let the display sleep")
    func idleSleeps() {
        let decision = decision(LoopTimerState())

        #expect(decision.keepsDisplayAwake == false)
        // Nothing running means no clock can change the answer — only a tap,
        // and a tap changes the state this is taken from.
        #expect(decision.holdsFor == nil)
    }

    // MARK: - Countdown

    @Test("A running countdown keeps the display awake until it ends")
    func runningCountdown() {
        var state = LoopTimerState()
        state.countdown = CountdownTimer(durationMinutes: 25)
        state.countdown.start(at: start)

        let decision = decision(state, after: 600)
        #expect(decision.keepsDisplayAwake)
        #expect(decision.holdsFor == TimeInterval(900))
    }

    @Test("A countdown on hold lets the display sleep")
    func pausedCountdown() {
        var state = LoopTimerState()
        state.countdown = CountdownTimer(durationMinutes: 25)
        state.countdown.start(at: start)
        state.countdown.pause(at: start.addingTimeInterval(60))

        #expect(decision(state, after: 120).keepsDisplayAwake == false)
    }

    @Test("A countdown that has run out lets the display sleep again")
    func finishedCountdown() {
        var state = LoopTimerState()
        state.countdown = CountdownTimer(durationMinutes: 25)
        state.countdown.start(at: start)

        // Nothing was tapped and nothing was written: the answer is taken from
        // the instant, which is the whole reason it cannot be left standing.
        #expect(decision(state, after: 25 * 60).keepsDisplayAwake == false)
        #expect(decision(state, after: 25 * 60).holdsFor == nil)
    }

    // MARK: - Interval

    @Test("A running interval keeps the display awake to the end of its block")
    func runningInterval() {
        var state = LoopTimerState()
        state.interval = IntervalTimer(focusMinutes: 25, breakMinutes: 5, rounds: 4)
        state.interval.start(at: start)

        // The block rather than the run, so the answer is re-taken at every
        // boundary and is still true if the run ends at one.
        let decision = decision(state, after: 60)
        #expect(decision.keepsDisplayAwake)
        #expect(decision.holdsFor == TimeInterval(24 * 60))
    }

    @Test("A break keeps the display awake as much as a focus block does")
    func runningBreak() {
        var state = LoopTimerState()
        state.interval = IntervalTimer(focusMinutes: 25, breakMinutes: 5, rounds: 4)
        state.interval.start(at: start)

        let decision = decision(state, after: 26 * 60)
        #expect(decision.keepsDisplayAwake)
        #expect(decision.holdsFor == TimeInterval(4 * 60))
    }

    @Test("An interval in setup, on hold or over lets the display sleep")
    func intervalWithoutARun() {
        var state = LoopTimerState()
        state.interval = IntervalTimer(focusMinutes: 25, breakMinutes: 5, rounds: 1)
        #expect(decision(state).keepsDisplayAwake == false)

        state.interval.start(at: start)
        state.interval.pause(at: start.addingTimeInterval(60))
        #expect(decision(state, after: 120).keepsDisplayAwake == false)

        state.interval.resume(at: start.addingTimeInterval(120))
        #expect(decision(state, after: 8 * 3_600).keepsDisplayAwake == false)
    }

    // MARK: - The stopwatch

    @Test("A running stopwatch does not keep the display awake")
    func runningStopwatch() {
        var state = LoopTimerState()
        state.countUp.start(at: start)

        // The decision the owner made: a count-up runs towards no moment, is
        // started and left, and holding the screen on against a run that never
        // ends is the failure the whole rule is written to avoid. The elapsed
        // time comes from a stored instant, so nothing is lost by sleeping.
        let decision = decision(state, after: 3_600)
        #expect(decision.keepsDisplayAwake == false)
        #expect(decision.holdsFor == nil)
    }

    @Test("A stopwatch running beside a countdown changes nothing")
    func stopwatchBesideACountdown() {
        var state = LoopTimerState()
        state.countUp.start(at: start)
        state.countdown = CountdownTimer(durationMinutes: 10)
        state.countdown.start(at: start)

        #expect(decision(state, after: 60).keepsDisplayAwake)
        #expect(decision(state, after: 60).holdsFor == TimeInterval(9 * 60))
        // And when the countdown is over, the stopwatch does not hold it on.
        #expect(decision(state, after: 10 * 60).keepsDisplayAwake == false)
    }

    // MARK: - Two runs at once

    @Test("With both running, the answer holds until whichever ends first")
    func soonestOfTwo() {
        var state = LoopTimerState()
        state.countdown = CountdownTimer(durationMinutes: 25)
        state.countdown.start(at: start)
        state.interval = IntervalTimer(focusMinutes: 5, breakMinutes: 5, rounds: 4)
        state.interval.start(at: start)

        let decision = decision(state, after: 60)
        #expect(decision.keepsDisplayAwake)
        #expect(decision.holdsFor == TimeInterval(4 * 60))
    }
}
