import Testing
import Foundation

@testable import Loop

// MARK: - Interval

@Suite("Interval")
struct IntervalTimerTests {

    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    /// The values the setup screen is drawn with: 25 focus, 5 break, 4 rounds.
    /// Its schedule runs 0…6900 s — seven blocks, the last one focus.
    private func standard() -> IntervalTimer {
        IntervalTimer(focusMinutes: 25, breakMinutes: 5, rounds: 4)
    }

    private func running(_ timer: IntervalTimer) -> IntervalTimer {
        var running = timer
        running.start(at: start)
        return running
    }

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    // MARK: - Schedule

    @Test("The last round has no break after it")
    func noBreakAfterTheLastRound() {
        let schedule = standard().schedule

        #expect(schedule.count == 7)
        #expect(schedule.filter { $0.kind == .focus }.count == 4)
        #expect(schedule.filter { $0.kind == .break }.count == 3)
        #expect(schedule.last?.kind == .focus)
        #expect(schedule.last?.round == 4)
        #expect(schedule.contains { $0.kind == .break && $0.round == 4 } == false)
    }

    @Test("A run is the focus blocks plus the breaks between them")
    func plannedDuration() {
        // Four rounds of 25 with 5-minute breaks is 1:55, not 2:00: the fourth
        // break does not exist.
        #expect(standard().plannedDuration == 6_900)
        #expect(standard().focusedDuration == 6_000)
    }

    @Test("A single round is one focus block and nothing else")
    func singleRound() {
        let timer = IntervalTimer(focusMinutes: 25, breakMinutes: 5, rounds: 1)

        #expect(timer.schedule.count == 1)
        #expect(timer.plannedDuration == 1_500)
    }

    // MARK: - Transitions

    @Test("Focus gives way to break and break to the next focus")
    func blockTransitions() {
        let timer = running(standard())

        #expect(timer.currentBlock(at: at(0))?.kind == .focus)
        #expect(timer.currentBlock(at: at(0))?.round == 1)

        #expect(timer.currentBlock(at: at(1_499))?.kind == .focus)

        #expect(timer.currentBlock(at: at(1_500))?.kind == .break)
        #expect(timer.currentBlock(at: at(1_500))?.round == 1)

        #expect(timer.currentBlock(at: at(1_800))?.kind == .focus)
        #expect(timer.currentBlock(at: at(1_800))?.round == 2)

        #expect(timer.currentBlock(at: at(5_400))?.kind == .focus)
        #expect(timer.currentBlock(at: at(5_400))?.round == 4)
    }

    @Test("The area drops back to zero at a block change")
    func fractionAtABlockBoundary() {
        let timer = running(standard())

        // A hair before the boundary the focus block is nearly full.
        #expect(abs(timer.fraction(at: at(1_499)) - 1_499 / 1_500) < 0.000_1)

        // On the boundary the break has just begun.
        #expect(timer.fraction(at: at(1_500)) == 0)
        #expect(timer.remaining(at: at(1_500)) == 300)

        // Half way through the break.
        #expect(timer.fraction(at: at(1_650)) == 0.5)
    }

    @Test("Remaining is the rest of the current block, not of the run")
    func remainingIsPerBlock() {
        let timer = running(standard())

        #expect(timer.remaining(at: at(600)) == 900)
        #expect(timer.remaining(at: at(1_620)) == 180)
    }

    // MARK: - Skip

    @Test("Skip is refused during a focus block")
    func skipRefusedDuringFocus() {
        var timer = running(standard())

        #expect(timer.canSkip(at: at(600)) == false)
        let skipped = timer.skip(at: at(600))
        #expect(skipped == false)

        // The focus block is untouched.
        #expect(timer.currentBlock(at: at(600))?.kind == .focus)
        #expect(timer.remaining(at: at(600)) == 900)
    }

    @Test("Skip during a break jumps to the next focus block")
    func skipDuringBreak() {
        var timer = running(standard())
        let skippedAt = at(1_560)

        #expect(timer.canSkip(at: skippedAt))
        let skipped = timer.skip(at: skippedAt)
        #expect(skipped)

        #expect(timer.currentBlock(at: skippedAt)?.kind == .focus)
        #expect(timer.currentBlock(at: skippedAt)?.round == 2)
        #expect(timer.remaining(at: skippedAt) == 1_500)
        #expect(timer.fraction(at: skippedAt) == 0)

        // And it keeps running from there rather than restarting the clock.
        #expect(timer.remaining(at: skippedAt.addingTimeInterval(60)) == 1_440)
    }

    @Test("Skip is refused while the run is held")
    func skipRefusedWhilePaused() {
        var timer = running(standard())
        timer.pause(at: at(1_560))

        #expect(timer.canSkip(at: at(1_560)) == false)
        let skipped = timer.skip(at: at(1_560))
        #expect(skipped == false)
    }

    @Test("Skipping the last break lands on the last focus block")
    func skipLastBreak() {
        var timer = running(standard())
        let skippedAt = at(5_200)

        let skipped = timer.skip(at: skippedAt)
        #expect(skipped)
        #expect(timer.currentBlock(at: skippedAt)?.round == 4)
        #expect(timer.currentBlock(at: skippedAt)?.kind == .focus)
    }

    // MARK: - Pause

    @Test("Resuming continues from the freeze, not from where wall time got to")
    func pauseAndResume() {
        var timer = running(standard())
        timer.pause(at: at(1_400))

        // Two hours held. Without the freeze this would be finished by now.
        let resumedAt = at(1_400 + 2 * 3_600)
        #expect(timer.phase(at: resumedAt) == .paused)
        #expect(timer.currentBlock(at: resumedAt)?.kind == .focus)
        #expect(timer.remaining(at: resumedAt) == 100)

        timer.resume(at: resumedAt)
        #expect(timer.remaining(at: resumedAt.addingTimeInterval(50)) == 50)

        // The block boundary is 100 s after the resume, not 100 s after the
        // pause.
        #expect(timer.currentBlock(at: resumedAt.addingTimeInterval(100))?.kind == .break)
    }

    // MARK: - Finish

    @Test("A run left going overnight comes back finished")
    func finishesWhileAway() {
        let timer = running(standard())
        let morning = at(9 * 3_600)

        #expect(timer.phase(at: morning) == .finished)
        #expect(timer.remaining(at: morning) == 0)
        #expect(timer.fraction(at: morning) == 1)

        // The pill still reads "Done · 4 of 4".
        #expect(timer.displayedBlock(at: morning).round == 4)
        #expect(timer.displayedBlock(at: morning).kind == .focus)
    }

    @Test("A run left in the background lands on the block its schedule reached")
    func restoresMidRun() {
        let timer = running(standard())
        let later = at(3_500)

        #expect(timer.phase(at: later) == .running)
        #expect(timer.currentBlock(at: later)?.kind == .break)
        #expect(timer.currentBlock(at: later)?.round == 2)
        #expect(timer.remaining(at: later) == 100)
    }

    @Test("The run ends with the last focus block, not with a break")
    func endsOnTheLastFocusBlock() {
        let timer = running(standard())

        #expect(timer.phase(at: at(6_899)) == .running)
        #expect(timer.currentBlock(at: at(6_899))?.kind == .focus)
        #expect(timer.phase(at: at(6_900)) == .finished)
    }

    @Test("Restart runs a finished interval again from round one")
    func restart() {
        var timer = running(standard())
        let restartedAt = at(9 * 3_600)

        let restarted = timer.start(at: restartedAt)
        #expect(restarted)
        #expect(timer.phase(at: restartedAt) == .running)
        #expect(timer.currentBlock(at: restartedAt)?.round == 1)
    }

    // MARK: - Zero-length blocks

    @Test("A zero-minute break is passed through, never shown")
    func zeroLengthBreak() {
        let timer = running(IntervalTimer(focusMinutes: 25, breakMinutes: 0, rounds: 2))

        #expect(timer.plannedDuration == 3_000)
        #expect(timer.currentBlock(at: at(1_500))?.kind == .focus)
        #expect(timer.currentBlock(at: at(1_500))?.round == 2)
        #expect(timer.fraction(at: at(1_500)) == 0)
    }

    @Test("A zero-minute focus leaves a run of breaks that still ends")
    func zeroLengthFocus() {
        let timer = running(IntervalTimer(focusMinutes: 0, breakMinutes: 5, rounds: 3))

        // Three empty focus blocks and two breaks: 10 minutes of run.
        #expect(timer.plannedDuration == 600)
        #expect(timer.currentBlock(at: at(0))?.kind == .break)
        #expect(timer.phase(at: at(600)) == .finished)
    }

    @Test("An interval with nothing in it cannot be started")
    func zeroLengthEverything() {
        var timer = IntervalTimer(focusMinutes: 0, breakMinutes: 0, rounds: 4)

        #expect(timer.canStart == false)
        let started = timer.start(at: start)
        #expect(started == false)
        #expect(timer.phase(at: start) == .setup)
    }

    // MARK: - Bounds

    @Test("Rounds stay between 1 and 99")
    func roundBounds() {
        #expect(IntervalTimer(rounds: 0).rounds == 1)
        #expect(IntervalTimer(rounds: -3).rounds == 1)
        #expect(IntervalTimer(rounds: 100).rounds == 99)

        var timer = standard()
        timer.setRounds(400, at: start)
        #expect(timer.rounds == 99)
        timer.setRounds(0, at: start)
        #expect(timer.rounds == 1)
    }

    @Test("The scales stay inside the ranges the design draws")
    func minuteBounds() {
        let timer = IntervalTimer(focusMinutes: 90, breakMinutes: 45, rounds: 4)
        #expect(timer.focusMinutes == 60)
        #expect(timer.breakMinutes == 30)
    }

    @Test("The setup values are the setup screen's, so a running interval ignores them")
    func setupIsSetupOnly() {
        var timer = running(standard())

        let focusChanged = timer.setFocusMinutes(10, at: at(60))
        let breakChanged = timer.setBreakMinutes(1, at: at(60))
        let roundsChanged = timer.setRounds(2, at: at(60))

        #expect(focusChanged == false)
        #expect(breakChanged == false)
        #expect(roundsChanged == false)
        #expect(timer.focusMinutes == 25)
        #expect(timer.breakMinutes == 5)
        #expect(timer.rounds == 4)
    }

    @Test("Reset returns to setup with the scales untouched")
    func reset() {
        var timer = running(standard())
        timer.reset()

        #expect(timer.phase(at: at(3_000)) == .setup)
        #expect(timer.focusMinutes == 25)
        #expect(timer.rounds == 4)
    }
}
