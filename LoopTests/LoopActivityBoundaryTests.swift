import Foundation
import Testing

@testable import Loop

// MARK: - Rolling over a block boundary

/// The Live Activity carries the block that follows the one it is counting, so
/// the lock screen can roll over at an instant the app is asleep for.
///
/// That "next block" is worked out from the three scales on a snapshot rather
/// than from `IntervalTimer.schedule`, because a snapshot is one frame and does
/// not hand out the schedule around it. This suite is what keeps the two from
/// drifting: it walks the engine's own schedule and demands the controller name
/// the same block at every boundary of it.
@Suite("Live Activity boundaries")
struct LoopActivityBoundaryTests {

    private let start = Date(timeIntervalSinceReferenceDate: 2_000_000)

    /// Configurations worth walking: the ordinary one, a single round with no
    /// break at all, back-to-back focus blocks, and a long run.
    nonisolated private static let configurations: [(focus: Int, rest: Int, rounds: Int)] = [
        (25, 5, 4),
        (25, 5, 1),
        (25, 0, 3),
        (1, 1, 2),
        (50, 10, 8)
    ]

    @Test("The block the Activity announces is the block the engine runs next", arguments: configurations)
    func upcomingMatchesTheSchedule(configuration: (focus: Int, rest: Int, rounds: Int)) {
        var timer = IntervalTimer(
            focusMinutes: configuration.focus,
            breakMinutes: configuration.rest,
            rounds: configuration.rounds
        )
        timer.start(at: start)

        let schedule = timer.schedule

        for (index, block) in schedule.enumerated() {
            // Zero-length blocks are stepped over by the engine rather than
            // shown, so they are never the block a frame is in.
            guard block.duration > 0 else { continue }

            let now = start.addingTimeInterval(block.start + block.duration / 2)
            let snapshot = timer.snapshot(at: now)

            #expect(snapshot.round == block.round)

            let blockEnd = now.addingTimeInterval(snapshot.remaining)
            let announced = LoopActivityController.upcoming(after: snapshot, endingAt: blockEnd)

            // Every block the engine actually runs after this one, zero-length
            // ones stepped over exactly as the engine steps over them.
            let expected = schedule[(index + 1)...]
                // A zero-length break is never a block the run is *in*, so it is
                // never a block the Activity should announce either.
                .filter { $0.duration > 0 && $0.end > block.end }
                .prefix(LoopActivityController.maxUpcomingBlocks)

            #expect(announced.count == expected.count)

            for (announcedBlock, expectedBlock) in zip(announced, expected) {
                #expect(announcedBlock.round == expectedBlock.round)
                #expect(announcedBlock.block == (expectedBlock.kind == .focus ? .focus : .rest))
                #expect(
                    abs(
                        announcedBlock.window.upperBound.timeIntervalSince(announcedBlock.window.lowerBound)
                            - expectedBlock.duration
                    ) < 0.001
                )
            }

            // The chain starts where this block ends and has no gaps in it.
            if let first = announced.first {
                #expect(first.window.lowerBound == blockEnd)
            }

            for (earlier, later) in zip(announced, announced.dropFirst()) {
                #expect(earlier.window.upperBound == later.window.lowerBound)
            }
        }
    }

    // MARK: - Rolling over

    @Test("A stale frame becomes the block that has actually started")
    func staleFrameRollsOver() throws {
        var timer = IntervalTimer(focusMinutes: 1, breakMinutes: 1, rounds: 2)
        timer.start(at: start)

        // Half a minute into the first focus block — the run the boundary
        // defect was found on.
        let now = start.addingTimeInterval(30)
        let snapshot = timer.snapshot(at: now)
        let window = LoopActivityController.window(
            remaining: snapshot.remaining,
            duration: snapshot.blockDuration,
            at: now
        )

        let state = LoopActivityAttributes.ContentState(
            block: .focus,
            round: snapshot.round,
            rounds: snapshot.rounds,
            window: window,
            pausedAt: nil,
            accentID: LoopAccent.petrol.rawValue,
            upcoming: LoopActivityController.upcoming(after: snapshot, endingAt: window.upperBound)
        )

        // Before the boundary there is nothing to roll over to, however stale
        // the render context claims to be.
        #expect(state.rolledOver(at: start.addingTimeInterval(50)) == nil)

        // Ten seconds past the first boundary: the break of round one, which is
        // what the engine is on too.
        let firstBoundary = try #require(state.rolledOver(at: start.addingTimeInterval(70)))
        #expect(firstBoundary.block == .rest)
        #expect(firstBoundary.round == 1)
        #expect(firstBoundary.window.lowerBound == window.upperBound)
        #expect(timer.snapshot(at: start.addingTimeInterval(70)).blockKind == .break)

        // And past the *second* boundary, from the same pushed state and with
        // no update in between: the focus block of round two. This is the case
        // that selecting on `isStale` alone got wrong — it would still be
        // showing the break of round one here.
        let secondBoundary = try #require(state.rolledOver(at: start.addingTimeInterval(130)))
        #expect(secondBoundary.block == .focus)
        #expect(secondBoundary.round == 2)
        #expect(timer.snapshot(at: start.addingTimeInterval(130)).blockKind == .focus)
        #expect(timer.snapshot(at: start.addingTimeInterval(130)).round == 2)

        // Past the whole run, the last block rather than a round from earlier.
        let afterTheEnd = try #require(state.rolledOver(at: start.addingTimeInterval(10_000)))
        #expect(afterTheEnd.round == 2)
        #expect(afterTheEnd.block == .focus)
    }

    @Test("A held run has no boundary to roll over")
    func aHeldRunDoesNotRollOver() {
        var timer = IntervalTimer(focusMinutes: 1, breakMinutes: 1, rounds: 2)
        timer.start(at: start)
        timer.pause(at: start.addingTimeInterval(30))

        let now = start.addingTimeInterval(30)
        let snapshot = timer.snapshot(at: now)
        let window = LoopActivityController.window(
            remaining: snapshot.remaining,
            duration: snapshot.blockDuration,
            at: now
        )

        let held = LoopActivityAttributes.ContentState(
            block: .focus,
            round: 1,
            rounds: 2,
            window: window,
            pausedAt: now,
            accentID: LoopAccent.petrol.rawValue,
            upcoming: LoopActivityController.upcoming(after: snapshot, endingAt: window.upperBound)
        )

        #expect(held.rolledOver(at: start.addingTimeInterval(10_000)) == nil)
    }
}
