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
            let upcoming = LoopActivityController.upcoming(after: snapshot, endingAt: blockEnd)

            // What the engine actually runs next: the first block that has not
            // ended by the time this one does.
            let expected = schedule[(index + 1)...].first { $0.end > block.end }

            guard let expected else {
                #expect(upcoming == nil, "nothing follows the last block")
                continue
            }

            guard let upcoming else {
                Issue.record("no block announced after \(block.kind) of round \(block.round)")
                continue
            }

            #expect(upcoming.round == expected.round)
            #expect(upcoming.block == (expected.kind == .focus ? .focus : .rest))
            #expect(upcoming.window.lowerBound == blockEnd)
            #expect(abs(upcoming.window.upperBound.timeIntervalSince(blockEnd) - expected.duration) < 0.001)
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

        let rolled = try #require(state.rolledOver())

        #expect(rolled.block == .rest)
        #expect(rolled.round == 1)
        #expect(rolled.window.lowerBound == window.upperBound)

        // The engine agrees: ten seconds past the boundary it is on the break.
        #expect(timer.snapshot(at: start.addingTimeInterval(70)).blockKind == .break)

        // And the roll-over is the end of the line — one boundary, not two.
        #expect(rolled.rolledOver() == nil)
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

        #expect(held.rolledOver() == nil)
    }
}
