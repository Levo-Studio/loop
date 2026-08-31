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
        #expect(timer.phase == .idle)
        #expect(timer.elapsed(at: start) == 0)
        #expect(timer.startDate == nil)
    }

    @Test("A running stopwatch counts the time that passed")
    func running() {
        var timer = CountUpTimer()
        timer.start(at: start)

        #expect(timer.phase == .running)
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
        #expect(timer.phase == .paused)
        #expect(timer.elapsed(at: resumedAt) == 30)

        timer.start(at: resumedAt)
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

        #expect(timer.phase == .idle)
        #expect(timer.elapsed(at: start.addingTimeInterval(600)) == 0)
    }

    @Test("A backwards system clock freezes rather than counting down")
    func backwardsClock() {
        var timer = CountUpTimer()
        timer.start(at: start)

        #expect(timer.elapsed(at: start.addingTimeInterval(-600)) == 0)
    }
}
