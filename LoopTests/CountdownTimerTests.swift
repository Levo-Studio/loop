import Testing
import Foundation

@testable import Loop

// MARK: - Countdown

@Suite("Countdown")
struct CountdownTimerTests {

    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test("The idle screen previews the whole duration")
    func idle() {
        let timer = CountdownTimer(durationMinutes: 25)
        #expect(timer.phase(at: start) == .idle)
        #expect(timer.remaining(at: start) == 25 * 60)
        #expect(timer.fraction(at: start) == 0)
    }

    @Test("A duration outside the scale is clamped to it")
    func durationBounds() {
        #expect(CountdownTimer(durationMinutes: 120).durationMinutes == 60)
        #expect(CountdownTimer(durationMinutes: -5).durationMinutes == 0)

        var timer = CountdownTimer(durationMinutes: 10)
        timer.setDuration(minutes: 99, at: start)
        #expect(timer.durationMinutes == 60)
    }

    @Test("The scale is the idle screen, so a running timer ignores it")
    func durationIsSetupOnly() {
        var timer = CountdownTimer(durationMinutes: 10)
        timer.start(at: start)

        let changed = timer.setDuration(minutes: 40, at: start)
        #expect(changed == false)
        #expect(timer.durationMinutes == 10)
    }

    @Test("A zero-minute countdown cannot be started")
    func zeroLengthCountdown() {
        var timer = CountdownTimer(durationMinutes: 0)

        #expect(timer.canStart == false)
        let started = timer.start(at: start)
        #expect(started == false)
        #expect(timer.phase(at: start) == .idle)
    }

    @Test("The area is the share of the duration that has gone")
    func fraction() {
        var timer = CountdownTimer(durationMinutes: 20)
        timer.start(at: start)

        #expect(timer.remaining(at: start.addingTimeInterval(300)) == 900)
        #expect(timer.fraction(at: start.addingTimeInterval(300)) == 0.25)
    }

    @Test("Resuming continues from the freeze")
    func pauseAndResume() {
        var timer = CountdownTimer(durationMinutes: 25)
        timer.start(at: start)
        timer.pause(at: start.addingTimeInterval(600))

        // Twenty minutes held changes nothing.
        let resumedAt = start.addingTimeInterval(1_800)
        #expect(timer.phase(at: resumedAt) == .paused)
        #expect(timer.remaining(at: resumedAt) == 900)

        timer.resume(at: resumedAt)
        #expect(timer.remaining(at: resumedAt.addingTimeInterval(60)) == 840)
        #expect(timer.phase(at: resumedAt.addingTimeInterval(60)) == .running)
    }

    @Test("A countdown that ran out in the background comes back finished")
    func finishesWhileAway() {
        var timer = CountdownTimer(durationMinutes: 25)
        timer.start(at: start)

        // Half an hour later on a 25-minute duration: over, and not sitting at
        // a negative remaining.
        let later = start.addingTimeInterval(30 * 60)
        #expect(timer.phase(at: later) == .finished)
        #expect(timer.remaining(at: later) == 0)
        #expect(timer.fraction(at: later) == 1)
    }

    @Test("A finished timer stays at zero however long it is left")
    func finishedStaysPut() {
        var timer = CountdownTimer(durationMinutes: 25)
        timer.start(at: start)
        timer.settle(at: start.addingTimeInterval(30 * 60))

        let muchLater = start.addingTimeInterval(6 * 3_600)
        #expect(timer.phase(at: muchLater) == .finished)
        #expect(timer.remaining(at: muchLater) == 0)
    }

    @Test("Pause is refused once the duration has run out")
    func pauseAfterFinish() {
        var timer = CountdownTimer(durationMinutes: 5)
        timer.start(at: start)

        let paused = timer.pause(at: start.addingTimeInterval(600))
        #expect(paused == false)
        #expect(timer.phase(at: start.addingTimeInterval(600)) == .finished)
    }

    @Test("Restart runs a finished timer again from the top")
    func restart() {
        var timer = CountdownTimer(durationMinutes: 5)
        timer.start(at: start)

        let restartedAt = start.addingTimeInterval(600)
        let restarted = timer.start(at: restartedAt)
        #expect(restarted)
        #expect(timer.phase(at: restartedAt) == .running)
        #expect(timer.remaining(at: restartedAt) == 300)
    }

    @Test("Reset keeps the duration the user picked")
    func reset() {
        var timer = CountdownTimer(durationMinutes: 40)
        timer.start(at: start)
        timer.reset()

        #expect(timer.phase(at: start) == .idle)
        #expect(timer.durationMinutes == 40)
        #expect(timer.remaining(at: start.addingTimeInterval(600)) == 40 * 60)
    }
}
