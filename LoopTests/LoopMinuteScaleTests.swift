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

        // The same tie on the stage boundary, where the neighbours are a
        // minute apart below and five above rather than five either side. It
        // is the first case a refactor of the tie rule gets wrong, because it
        // is the only one where "halfway" is not halfway between detents of
        // equal width.
        #expect(duration.nearest(to: 119.5) == 119)

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

    // MARK: - The detent coordinate

    @Test("Below two hours a detent is a minute, so the drawn scale is unchanged")
    func detentOffsetInTheFineStage() {
        // The export lays a scale out in equal slots, one per minute. Every
        // value the export could draw has to keep the position it had, or the
        // one part of the geometry that was actually drawn stops matching it.
        for minutes in stride(from: 0, through: 120, by: 1) {
            #expect(duration.detentOffset(of: Double(minutes)) == Double(minutes))
        }

        // And between them, because a finger is between detents for all but an
        // instant of a drag.
        #expect(duration.detentOffset(of: 45.5) == 45.5)
    }

    @Test("Above two hours a slot is five minutes, not one")
    func detentOffsetInTheCoarseStage() {
        // 120 minutes of detents, then one per five minutes. The whole point of
        // the change: the scale stops stretching over values nothing can land
        // on.
        #expect(duration.detentOffset(of: 125) == 121)
        #expect(duration.detentOffset(of: 180) == 132)
        #expect(duration.detentOffset(of: 122.5) == 120.5)

        // Thirty hours: 120 + (1800 - 120) / 5.
        #expect(duration.detentOffset(of: 1_800) == 456)

        // Which is what makes it reachable by hand. At the export's density —
        // 61 slots across the scale — the full range is 456 slots rather than
        // 1800, so it is a seventh of the dragging it was.
        #expect(duration.detentOffset(of: 1_800) / 61 < 8)
    }

    @Test("A position on the scale and the value under it are each other's inverse")
    func detentOffsetRoundTrips() {
        for minutes in [0, 1, 59, 119, 120, 121.5, 125, 480, 1_000, 1_799.5, 1_800] as [Double] {
            let there = duration.detentOffset(of: minutes)
            #expect(abs(duration.minutes(atDetentOffset: there) - minutes) < 0.000_1)
        }

        // Monotonic across the boundary, or the scale would run backwards under
        // the finger somewhere.
        var previous = -1.0
        for minutes in stride(from: 0.0, through: 1_800.0, by: 0.5) {
            let there = duration.detentOffset(of: minutes)
            #expect(there > previous)
            previous = there
        }
    }

    @Test("A position past either end answers the end")
    func detentOffsetSaturates() {
        #expect(duration.minutes(atDetentOffset: -50) == 0)
        #expect(duration.minutes(atDetentOffset: 10_000) == 1_800)
        #expect(duration.detentOffset(of: -50) == 0)
        #expect(duration.detentOffset(of: 10_000) == 456)

        // A non-finite position is a bug upstream and must not become a
        // duration nobody can explain.
        #expect(duration.detentOffset(of: .nan) == 0)
        #expect(duration.minutes(atDetentOffset: .nan) == 0)
    }

    @Test("The step at a value is the grid the drawing asks for")
    func stepAtAValue() {
        // The number row needs to know that the detents have stopped being
        // minutes without knowing where that happens.
        #expect(duration.step(at: 0) == 1)
        #expect(duration.step(at: 119) == 1)
        #expect(duration.step(at: 120) == 5)
        #expect(duration.step(at: 1_800) == 5)

        // Out of range answers the nearest end rather than nothing.
        #expect(duration.step(at: -10) == 1)
        #expect(duration.step(at: 100_000) == 5)
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

        // And the position too: 120 one-minute slots, then 264 five-minute
        // ones, then 96 of a quarter of an hour. A third stage costs the
        // drawing nothing because it never asks where the boundaries are.
        #expect(scale.detentOffset(of: Double(24 * 60)) == 384)
        #expect(scale.detentOffset(of: Double(48 * 60)) == 480)
        #expect(scale.minutes(atDetentOffset: 384) == Double(24 * 60))
        #expect(scale.minutes(atDetentOffset: 480) == Double(48 * 60))

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
