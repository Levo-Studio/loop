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
            accentID: LoopAccent.petrol.rawValue,
            upcoming: []
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

    @Test("A held run is marked held")
    func aHeldRunIsMarkedHeld() {
        #expect(state(remaining: 300, duration: 1_500, paused: true).isPaused)
        #expect(!state(remaining: 300, duration: 1_500).isPaused)
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
            accentID: LoopAccent.petrol.rawValue,
            upcoming: []
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
            accentID: LoopAccent.petrol.rawValue,
            upcoming: []
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

    // MARK: - The budget

    @Test("A fully loaded state stays inside ActivityKit's four kilobytes")
    func aFullStateFitsTheBudget() throws {
        // The worst case the controller can produce: the longest scales, the
        // most blocks it will carry, and every field at its widest.
        var timer = IntervalTimer(focusMinutes: 60, breakMinutes: 30, rounds: 99)
        timer.start(at: now)

        let snapshot = timer.snapshot(at: now.addingTimeInterval(1))
        let window = LoopActivityController.window(
            remaining: snapshot.remaining,
            duration: snapshot.blockDuration,
            at: now
        )
        let full = LoopActivityAttributes.ContentState(
            block: .focus,
            round: snapshot.round,
            rounds: snapshot.rounds,
            window: window,
            pausedAt: nil,
            accentID: LoopAccent.graphite.rawValue,
            upcoming: LoopActivityController.upcoming(after: snapshot, endingAt: window.upperBound)
        )

        #expect(full.upcoming.count == LoopActivityController.maxUpcomingBlocks)

        let encoded = try JSONEncoder().encode(full)
        #expect(encoded.count < 4_096, "content state is \(encoded.count) bytes")
    }

    // MARK: - Hours

    @Test("The hour field is decided by the block, not by what is left of it")
    func hoursFollowTheBlockLength() {
        #expect(state(remaining: 60, duration: 3_600).showsHours)
        #expect(!state(remaining: 60, duration: 1_500).showsHours)
    }

    // MARK: - Reserving room for the digits

    @Test("The longest string a block can print is counted from the block, not from what is left")
    func theDigitsAreCountedFromTheBlock() {
        // "25:00"
        #expect(state(remaining: 60, duration: 1_500).timeCharacters == 5)

        // "1:00:00", and still seven once it has narrowed to "59:59" — the
        // island holds its width rather than jumping a character at the hour.
        #expect(state(remaining: 60, duration: 3_600).timeCharacters == 7)
        #expect(state(remaining: 60, duration: 5_400).timeCharacters == 7)

        // "30:00:00", the top of the countdown scale.
        #expect(state(remaining: 60, duration: 30 * 3_600).timeCharacters == 8)
    }
}
