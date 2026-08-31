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

    @Test("A break held for hours resumes into the focus block that follows it")
    func pauseDuringABreakAcrossTheBoundary() {
        var timer = running(standard())

        // 60 s into the first break, held for three hours.
        timer.pause(at: at(1_560))
        let resumedAt = at(1_560 + 3 * 3_600)

        #expect(timer.phase(at: resumedAt) == .paused)
        #expect(timer.snapshot(at: resumedAt).blockKind == .break)
        #expect(timer.remaining(at: resumedAt) == 240)

        timer.resume(at: resumedAt)

        // The remaining 240 s of break run from the resume, and the run then
        // carries on into round two rather than skipping it.
        #expect(timer.snapshot(at: resumedAt.addingTimeInterval(239)).blockKind == .break)

        let afterBoundary = timer.snapshot(at: resumedAt.addingTimeInterval(240))
        #expect(afterBoundary.blockKind == .focus)
        #expect(afterBoundary.round == 2)
        #expect(afterBoundary.fraction == 0)
        #expect(afterBoundary.remaining == 1_500)
    }

    @Test("The area freezes while the run is held and carries on from there")
    func fractionFreezesWhileHeld() {
        var timer = running(standard())
        timer.pause(at: at(750))

        // Four hours held. Without the freeze the whole run would be over.
        let heldFor = at(750 + 4 * 3_600)
        #expect(timer.fraction(at: at(750)) == 0.5)
        #expect(timer.fraction(at: heldFor) == 0.5)
        #expect(timer.snapshot(at: heldFor).fraction == 0.5)
        #expect(timer.snapshot(at: heldFor).blockKind == .focus)

        timer.resume(at: heldFor)
        #expect(timer.fraction(at: heldFor.addingTimeInterval(375)) == 0.75)
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
        let snapshot = timer.snapshot(at: morning)
        #expect(snapshot.round == 4)
        #expect(snapshot.rounds == 4)
        #expect(snapshot.blockKind == .focus)
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

    @Test("A zero-minute focus cannot be started, so no run opens on a break")
    func zeroLengthFocus() {
        // Otherwise the pill would read "Break · Round 01 / 03" before anything
        // had been worked on, and the finished screen would report no time
        // focused at all.
        var timer = IntervalTimer(focusMinutes: 0, breakMinutes: 5, rounds: 3)

        #expect(timer.snapshot(at: start).canStart == false)
        let started = timer.start(at: start)
        #expect(started == false)
        #expect(timer.phase(at: start) == .setup)
    }

    @Test("A timer in setup has no area, and neither has one that was reset")
    func noAreaBeforeAStart() {
        // The setup screen is sliders and a stepper. An area rising behind them
        // would look deliberate, which is why nobody would report it.
        #expect(standard().fraction(at: start) == 0)
        #expect(standard().snapshot(at: start).phase == .setup)
        #expect(standard().snapshot(at: start).round == 1)

        var timer = running(standard())
        timer.reset()
        #expect(timer.fraction(at: at(3_000)) == 0)
    }

    @Test("A snapshot answers the whole frame at one instant")
    func snapshot() {
        let timer = running(standard())

        let focus = timer.snapshot(at: at(600))
        #expect(focus.phase == .running)
        #expect(focus.blockKind == .focus)
        #expect(focus.round == 1)
        #expect(focus.rounds == 4)
        #expect(focus.remaining == 900)
        #expect(focus.blockDuration == 1_500)
        #expect(focus.fraction == 0.4)
        #expect(focus.canSkip == false)

        // On the boundary every field belongs to the break — the pill and the
        // fraction cannot disagree, because they come from one reading.
        let boundary = timer.snapshot(at: at(1_500))
        #expect(boundary.blockKind == .break)
        #expect(boundary.round == 1)
        #expect(boundary.fraction == 0)
        #expect(boundary.remaining == 300)
        #expect(boundary.canSkip)
    }

    @Test("The snapshot carries the three scales and whether start is live")
    func snapshotCarriesTheControls() {
        #expect(IntervalTimer(focusMinutes: 0, breakMinutes: 5, rounds: 4).snapshot(at: start).canStart == false)
        #expect(standard().snapshot(at: start).canStart)

        var timer = standard()
        let setup = timer.snapshot(at: start)
        #expect(setup.focusMinutes == 25)
        #expect(setup.breakMinutes == 5)
        #expect(setup.rounds == 4)

        // What the scales and the stepper write comes back on the next frame.
        timer.setFocusMinutes(50, at: start)
        timer.setBreakMinutes(10, at: start)
        timer.setRounds(3, at: start)

        let changed = timer.snapshot(at: start)
        #expect(changed.focusMinutes == 50)
        #expect(changed.breakMinutes == 10)
        #expect(changed.rounds == 3)

        // And they stay readable through a run, where the pill needs the round
        // total and the screen still draws the scales behind it.
        timer.start(at: start)
        #expect(timer.snapshot(at: at(60)).focusMinutes == 50)
        #expect(timer.snapshot(at: at(60)).rounds == 3)
    }

    @Test("The two totals are the only values a screen reads off the timer")
    func totalsAreNotOnTheSnapshot() {
        // Named in the snapshot's documentation so nobody takes them for an
        // oversight — and so nobody prints blockDuration in their place.
        let timer = standard()

        #expect(timer.plannedDuration == 6_900)
        #expect(timer.focusedDuration == 6_000)
        #expect(timer.snapshot(at: start).blockDuration == 1_500)
    }

    @Test("A reading exactly on a boundary instant belongs to the next block")
    func boundaryInstant() {
        let timer = running(standard())

        // Every boundary of the run, read at the instant itself.
        #expect(timer.snapshot(at: at(0)).blockKind == .focus)
        #expect(timer.snapshot(at: at(1_500)).blockKind == .break)
        #expect(timer.snapshot(at: at(1_800)).blockKind == .focus)
        #expect(timer.snapshot(at: at(1_800)).round == 2)
        #expect(timer.snapshot(at: at(3_300)).blockKind == .break)
        #expect(timer.snapshot(at: at(5_400)).round == 4)
        #expect(timer.snapshot(at: at(6_900)).phase == .finished)

        // And each of them starts its block at zero, not at a hair over.
        #expect(timer.snapshot(at: at(1_500)).fraction == 0)
        #expect(timer.snapshot(at: at(1_800)).fraction == 0)
    }

    @Test("A single round has no skippable moment anywhere in it")
    func singleRoundHasNothingToSkip() {
        var timer = running(IntervalTimer(focusMinutes: 25, breakMinutes: 5, rounds: 1))

        for second in stride(from: 0, through: 1_500, by: 100) {
            #expect(timer.canSkip(at: at(TimeInterval(second))) == false)
        }

        let skipped = timer.skip(at: at(750))
        #expect(skipped == false)
        #expect(timer.remaining(at: at(750)) == 750)
    }

    @Test("An interval with nothing in it cannot be started")
    func zeroLengthEverything() {
        var timer = IntervalTimer(focusMinutes: 0, breakMinutes: 0, rounds: 4)

        #expect(timer.snapshot(at: start).canStart == false)
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
