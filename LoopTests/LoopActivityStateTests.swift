import Foundation
import Testing

@testable import Loop

// MARK: - Live Activity state

@Suite("Live Activity state")
struct LoopActivityStateTests {

    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func state(
        block: LoopActivityAttributes.Block = .countdown,
        remaining: TimeInterval,
        duration: TimeInterval,
        paused: Bool = false
    ) -> LoopActivityAttributes.ContentState {
        LoopActivityAttributes.ContentState(
            block: block,
            round: 1,
            rounds: 1,
            window: LoopActivityController.window(remaining: remaining, duration: duration, at: now),
            pausedAt: paused ? now : nil,
            accentID: LoopAccent.petrol.rawValue
        )
    }

    // MARK: - The window

    @Test("The window ends where the block runs out and is as long as the block")
    func windowSpansTheBlock() {
        let window = LoopActivityController.window(remaining: 300, duration: 1_500, at: now)

        #expect(window.upperBound == now.addingTimeInterval(300))
        #expect(window.lowerBound == now.addingTimeInterval(300 - 1_500))
    }

    @Test("A zero-length block still gets a window iOS can count inside")
    func zeroLengthBlockKeepsARange() {
        let window = LoopActivityController.window(remaining: 0, duration: 0, at: now)

        #expect(window.upperBound > window.lowerBound)
    }

    // MARK: - Pausing

    @Test("A held run reports the fraction it was held at")
    func pausedFractionMatchesTheElapsedShare() {
        // Twenty of twenty-five minutes gone.
        let held = state(remaining: 300, duration: 1_500, paused: true)

        #expect(abs(held.pausedFraction - 0.8) < 0.000_1)
        #expect(held.isPaused)
    }

    @Test("A running run has no held fraction to draw")
    func runningHasNoPausedFraction() {
        #expect(state(remaining: 300, duration: 1_500).pausedFraction == 0)
    }

    // MARK: - When an update is worth sending

    @Test("A second later, a running block is not worth an update")
    func aTickDoesNotMoveARunningBlock() {
        let first = state(remaining: 300, duration: 1_500)
        let second = LoopActivityAttributes.ContentState(
            block: .countdown,
            round: 1,
            rounds: 1,
            window: LoopActivityController.window(
                remaining: 299,
                duration: 1_500,
                at: now.addingTimeInterval(1)
            ),
            pausedAt: nil,
            accentID: LoopAccent.petrol.rawValue
        )

        #expect(!LoopActivityController.hasMoved(from: first, to: second))
    }

    @Test("A held run is never worth an update, however long it is held")
    func aHeldRunIsNeverPushedAgain() {
        let first = state(remaining: 300, duration: 1_500, paused: true)
        let later = LoopActivityAttributes.ContentState(
            block: .countdown,
            round: 1,
            rounds: 1,
            window: LoopActivityController.window(
                remaining: 300,
                duration: 1_500,
                at: now.addingTimeInterval(3_600)
            ),
            pausedAt: now.addingTimeInterval(3_600),
            accentID: LoopAccent.petrol.rawValue
        )

        #expect(!LoopActivityController.hasMoved(from: first, to: later))
    }

    @Test("Holding and letting go are both worth an update")
    func pausingAndResumingArePushed() {
        let running = state(remaining: 300, duration: 1_500)
        let held = state(remaining: 300, duration: 1_500, paused: true)

        #expect(LoopActivityController.hasMoved(from: running, to: held))
        #expect(LoopActivityController.hasMoved(from: held, to: running))
    }

    @Test("A block boundary is worth an update")
    func aBlockBoundaryIsPushed() {
        let focus = state(block: .focus, remaining: 1, duration: 1_500)
        let rest = state(block: .rest, remaining: 300, duration: 300)

        #expect(LoopActivityController.hasMoved(from: focus, to: rest))
    }

    // MARK: - Hours

    @Test("The hour field is decided by the block, not by what is left of it")
    func hoursFollowTheBlockLength() {
        #expect(state(remaining: 60, duration: 3_600).showsHours)
        #expect(!state(remaining: 60, duration: 1_500).showsHours)
    }
}
