import Testing
import Foundation

@testable import Loop

// MARK: - Count-up

@Suite("Count-up")
struct CountUpTimerTests {

    /// A fixed instant, so no test depends on the wall clock or has to wait for
    /// one.
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test("A fresh stopwatch is idle at zero")
    func idle() {
        let timer = CountUpTimer()
        #expect(timer.phase(at: start) == .idle)
        #expect(timer.elapsed(at: start) == 0)
        #expect(timer.startDate == nil)
    }

    @Test("A running stopwatch counts the time that passed")
    func running() {
        var timer = CountUpTimer()
        timer.start(at: start)

        #expect(timer.phase(at: start) == .running)
        #expect(timer.elapsed(at: start.addingTimeInterval(90)) == 90)
        #expect(timer.startDate == start)
    }

    @Test("Resuming continues from the freeze, not from where wall time got to")
    func pauseAndResume() {
        var timer = CountUpTimer()
        timer.start(at: start)
        timer.pause(at: start.addingTimeInterval(30))

        // An hour spent paused adds nothing.
        let resumedAt = start.addingTimeInterval(3_630)
        #expect(timer.phase(at: resumedAt) == .paused)
        #expect(timer.elapsed(at: resumedAt) == 30)

        timer.resume(at: resumedAt)
        #expect(timer.elapsed(at: resumedAt.addingTimeInterval(10)) == 40)

        // The line under the time says "since 09:29", which is the first start,
        // not the resume.
        #expect(timer.startDate == start)
    }

    @Test("Reset returns the page to idle")
    func reset() {
        var timer = CountUpTimer()
        timer.start(at: start)
        timer.reset()

        #expect(timer.phase(at: start) == .idle)
        #expect(timer.elapsed(at: start.addingTimeInterval(600)) == 0)
    }

    @Test("Start does not double as resume, and resume does not double as start")
    func startAndResumeAreDistinct() {
        var timer = CountUpTimer()

        let resumedWhileIdle = timer.resume(at: start)
        #expect(resumedWhileIdle == false)

        timer.start(at: start)
        let startedWhileRunning = timer.start(at: start.addingTimeInterval(10))
        #expect(startedWhileRunning == false)

        // The second start must not have moved the beginning of the run.
        #expect(timer.startDate == start)
        #expect(timer.elapsed(at: start.addingTimeInterval(10)) == 10)
    }

    @Test("A snapshot answers the whole frame at one instant")
    func snapshot() {
        var timer = CountUpTimer()
        timer.start(at: start)

        let snapshot = timer.snapshot(at: start.addingTimeInterval(65))
        #expect(snapshot.phase == .running)
        #expect(snapshot.elapsed == 65)
        #expect(snapshot.startDate == start)
    }

    @Test("A backwards system clock freezes rather than counting down")
    func backwardsClock() {
        var timer = CountUpTimer()
        timer.start(at: start)

        #expect(timer.elapsed(at: start.addingTimeInterval(-600)) == 0)
    }
}
