import Testing
import Foundation

@testable import Loop

// MARK: - Minute scale

@Suite("Minute scale")
struct LoopMinuteScaleTests {

    private let duration = LoopTimerLimits.duration

    // MARK: - The stage boundary

    @Test("Two hours is reachable from below in minutes and left in fives")
    func stageBoundaryUpwards() {
        // The boundary is the one value that belongs to both stages, so it is
        // where an off-by-one hides: a step that skipped it would make 2:00 —
        // the most likely long value anybody picks — unreachable.
        #expect(duration.next(after: 118) == 119)
        #expect(duration.next(after: 119) == 120)
        #expect(duration.next(after: 120) == 125)
        #expect(duration.next(after: 121) == 125)
    }

    @Test("Coming back down through two hours returns to whole minutes")
    func stageBoundaryDownwards() {
        #expect(duration.previous(before: 125) == 120)
        #expect(duration.previous(before: 121) == 120)
        #expect(duration.previous(before: 120) == 119)
        #expect(duration.previous(before: 119) == 118)
    }

    @Test("Only the staged values are selectable")
    func selectability() {
        #expect(duration.isSelectable(0))
        #expect(duration.isSelectable(119))
        #expect(duration.isSelectable(120))
        #expect(duration.isSelectable(121) == false)
        #expect(duration.isSelectable(124) == false)
        #expect(duration.isSelectable(125))

        // Out of range is not a detent, however well the arithmetic works out.
        #expect(duration.isSelectable(-5) == false)
        #expect(duration.isSelectable(30 * 60 + 5) == false)
    }

    // MARK: - Landing between detents

    @Test("A value between two detents resolves to the closer one")
    func nearestFromBetween() {
        #expect(duration.nearest(to: 121) == 120)
        #expect(duration.nearest(to: 122) == 120)
        #expect(duration.nearest(to: 123) == 125)
        #expect(duration.nearest(to: 124) == 125)

        // A value already on a detent is its own answer.
        #expect(duration.nearest(to: 120) == 120)
        #expect(duration.nearest(to: 45) == 45)
    }

    @Test("A scroll offset resolves from a fraction of a minute")
    func nearestFromAnOffset() {
        #expect(duration.nearest(to: 122.4) == 120)
        #expect(duration.nearest(to: 122.6) == 125)

        // Exactly halfway settles on the value already travelled past, so a
        // released picker never jumps forward past where it was let go.
        #expect(duration.nearest(to: 122.5) == 120)

        #expect(duration.nearest(to: 44.9) == 45)
        #expect(duration.nearest(to: 45.4) == 45)

        // A non-finite offset is a bug upstream; it must not propagate as a
        // duration nobody can explain.
        #expect(duration.nearest(to: Double.nan) == 0)
    }

    // MARK: - The ends

    @Test("Each scale saturates at its own ends")
    func ends() {
        #expect(duration.range == 0...(30 * 60))
        #expect(LoopTimerLimits.focus.range == 0...(8 * 60))
        #expect(LoopTimerLimits.breakLength.range == 0...(2 * 60))
        #expect(LoopTimerLimits.rounds == 1...99)

        for scale in [duration, LoopTimerLimits.focus, LoopTimerLimits.breakLength] {
            // Both ends have to be detents, or the end of a scrolling scale
            // would be a place the picker can never come to rest.
            #expect(scale.isSelectable(scale.range.lowerBound))
            #expect(scale.isSelectable(scale.range.upperBound))

            #expect(scale.previous(before: scale.range.lowerBound) == scale.range.lowerBound)
            #expect(scale.next(after: scale.range.upperBound) == scale.range.upperBound)

            #expect(scale.nearest(to: scale.range.lowerBound - 1_000) == scale.range.lowerBound)
            #expect(scale.nearest(to: scale.range.upperBound + 1_000) == scale.range.upperBound)
        }
    }

    @Test("The break stays on whole minutes over its whole length")
    func breakIsUnstaged() {
        // It ends where the coarse stage begins, which is the reason the one
        // scale set between three and fifteen minutes never loses the minute.
        let scale = LoopTimerLimits.breakLength

        #expect(scale.next(after: 118) == 119)
        #expect(scale.next(after: 119) == 120)
        #expect(scale.isSelectable(37))
    }

    // MARK: - Adding a stage

    @Test("A third stage needs no change to anything that asks a question")
    func aThirdStage() {
        // The staging is data. This is the check that it is: a scale nobody
        // shipped, answering the same four questions correctly.
        let scale = LoopMinuteScale(
            range: 0...(48 * 60),
            stages: [
                .init(start: 0, step: 1),
                .init(start: 2 * 60, step: 5),
                .init(start: 24 * 60, step: 15)
            ]
        )

        #expect(scale.next(after: 24 * 60 - 5) == 24 * 60)
        #expect(scale.next(after: 24 * 60) == 24 * 60 + 15)
        #expect(scale.previous(before: 24 * 60) == 24 * 60 - 5)
        #expect(scale.isSelectable(24 * 60 + 5) == false)
        #expect(scale.nearest(to: 24 * 60 + 5) == 24 * 60)
        #expect(scale.nearest(to: 24 * 60 + 8) == 24 * 60 + 15)

        // Unsorted input is put in order rather than answering nonsense.
        let unsorted = LoopMinuteScale(
            range: 0...(4 * 60),
            stages: [.init(start: 2 * 60, step: 5), .init(start: 0, step: 1)]
        )
        #expect(unsorted.next(after: 119) == 120)
        #expect(unsorted.next(after: 120) == 125)
    }

    // MARK: - What the new maximum prints

    @Test("The formatters still read as time at the new maxima")
    func formattersAtTheMaximum() {
        // Thirty hours: the countdown's own display, hours never folded into a
        // day.
        #expect(LoopTimeFormat.clock(seconds: 30 * 3_600) == "30:00:00")
        #expect(LoopTimeFormat.remaining(TimeInterval(30 * 3_600)) == "30:00:00")
        #expect(LoopTimeFormat.elapsed(TimeInterval(30 * 3_600)) == "30:00:00")
        #expect(LoopTimeFormat.hoursAndMinutes(TimeInterval(30 * 3_600)) == "30:00")

        // And the longest total the interval scales can add up to: 99 focus
        // blocks of eight hours with 98 two-hour breaks between them.
        let longestSeconds: Int = 99 * 8 * 3_600 + 98 * 2 * 3_600
        #expect(LoopTimeFormat.hoursAndMinutes(TimeInterval(longestSeconds)) == "988:00")
        #expect(LoopTimeFormat.clock(seconds: longestSeconds) == "988:00:00")
    }
}
