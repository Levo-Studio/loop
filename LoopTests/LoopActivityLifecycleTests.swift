import Foundation
import Testing

@testable import Loop

// MARK: - When the card belongs on the lock screen

/// Whether a frame wants a Live Activity at all, for every way a run can begin
/// and every way it can end.
///
/// This is the half of the controller a defect reached a device through. A
/// stopped countdown kept its card, and a held one went on counting down on the
/// lock screen, because the frame carrying the new phase never reached the
/// controller at all — the screen drove it from its tick loop, and that loop
/// returns the moment the phase stops being `.running`. The decision itself was
/// right and unreachable, which is exactly the kind of rightness a test has to
/// be able to see.
///
/// So the decision is a value now, and this suite walks it with the real
/// engines rather than with hand-built snapshots: Stop, Reset, Restart, Skip
/// and a run reaching its own end are all things the engine does, and each one
/// has an answer here.
@Suite("Live Activity lifecycle")
struct LoopActivityLifecycleTests {

    private let now = Date(timeIntervalSinceReferenceDate: 3_000_000)

    private let accent = LoopAccent.amber

    /// The dates are whole seconds apart, so the arithmetic is exact in a
    /// `Double`; this is here for the two places that add a window's length to
    /// an instant and compare, where a last-bit difference would be noise
    /// rather than a finding.
    private let tolerance: TimeInterval = 0.001

    // MARK: - Countdown

    private func card(_ timer: CountdownTimer, at instant: Date) -> LoopActivityAttributes.ContentState? {
        LoopActivityController.state(countdown: timer.snapshot(at: instant), accent: accent, at: instant)
    }

    @Test("A countdown that has not been started has no card")
    func anIdleCountdownHasNoCard() {
        #expect(card(CountdownTimer(durationMinutes: 25), at: now) == nil)
    }

    @Test("A running countdown has a card counting its own window")
    func aRunningCountdownHasACard() throws {
        var timer = CountdownTimer(durationMinutes: 25)
        timer.start(at: now)

        let instant = now.addingTimeInterval(60)
        let state = try #require(card(timer, at: instant))

        #expect(state.block == .countdown)
        #expect(!state.isPaused)
        #expect(state.accentID == accent.rawValue)
        #expect(abs(state.duration - 1_500) < tolerance)
        // The window ends where the run does — a minute in, that is still 25
        // minutes after it started.
        #expect(abs(state.window.upperBound.timeIntervalSince(now) - 1_500) < tolerance)
    }

    @Test("A held countdown has a card, and the card says it is held")
    func aHeldCountdownIsMarkedHeld() throws {
        var timer = CountdownTimer(durationMinutes: 25)
        timer.start(at: now)
        timer.pause(at: now.addingTimeInterval(60))

        // Half a minute after it was held, so a window that walked on with the
        // clock would show.
        let instant = now.addingTimeInterval(90)
        let state = try #require(card(timer, at: instant))

        #expect(state.isPaused)
        #expect(state.pausedAt == instant)
        // The digits a held card prints are `end − pausedAt`, so this is the
        // 24 minutes the page shows rather than what the clock has reached.
        #expect(abs(state.window.upperBound.timeIntervalSince(instant) - 1_440) < tolerance)
    }

    @Test("Stopping a countdown takes the card away", arguments: [false, true])
    func stoppingACountdownEndsTheCard(afterHolding: Bool) {
        var timer = CountdownTimer(durationMinutes: 25)
        timer.start(at: now)
        if afterHolding { timer.pause(at: now.addingTimeInterval(60)) }
        timer.reset()

        #expect(card(timer, at: now.addingTimeInterval(120)) == nil)
    }

    @Test("A countdown that runs out takes the card away")
    func aFinishedCountdownEndsTheCard() {
        var timer = CountdownTimer(durationMinutes: 25)
        timer.start(at: now)

        let afterTheEnd = now.addingTimeInterval(1_501)
        #expect(timer.snapshot(at: afterTheEnd).phase == .finished)
        #expect(card(timer, at: afterTheEnd) == nil)
    }

    @Test("Restarting a finished countdown puts a card back")
    func restartingACountdownStartsACard() {
        var timer = CountdownTimer(durationMinutes: 25)
        timer.start(at: now)
        timer.commitTransitions(at: now.addingTimeInterval(1_501))

        let restart = now.addingTimeInterval(1_600)
        timer.start(at: restart)

        #expect(card(timer, at: restart) != nil)
    }

    @Test("Every phase the countdown can be in has an answer", arguments: CountdownTimer.Phase.allCases)
    func everyCountdownPhaseIsAnswered(phase: CountdownTimer.Phase) {
        var timer = CountdownTimer(durationMinutes: 25)
        var instant = now.addingTimeInterval(60)

        switch phase {
        case .idle:
            break
        case .running:
            timer.start(at: now)
        case .paused:
            timer.start(at: now)
            timer.pause(at: now.addingTimeInterval(30))
        case .finished:
            timer.start(at: now)
            instant = now.addingTimeInterval(1_501)
        }

        #expect(timer.snapshot(at: instant).phase == phase)

        // A card exists exactly while a run does. The two phases that are not a
        // run are the two whose card had been surviving.
        let wantsACard = phase == .running || phase == .paused
        #expect((card(timer, at: instant) != nil) == wantsACard)
    }

    // MARK: - Interval

    private func card(_ timer: IntervalTimer, at instant: Date) -> LoopActivityAttributes.ContentState? {
        LoopActivityController.state(interval: timer.snapshot(at: instant), accent: accent, at: instant)
    }

    @Test("An interval in setup has no card")
    func anIntervalInSetupHasNoCard() {
        #expect(card(IntervalTimer(focusMinutes: 25, breakMinutes: 5, rounds: 4), at: now) == nil)
    }

    @Test("A running interval has a card naming its block and round")
    func aRunningIntervalHasACard() throws {
        var timer = IntervalTimer(focusMinutes: 25, breakMinutes: 5, rounds: 4)
        timer.start(at: now)

        // A minute into the break of the first round.
        let instant = now.addingTimeInterval(25 * 60 + 60)
        let state = try #require(card(timer, at: instant))

        #expect(state.block == .rest)
        #expect(state.round == 1)
        #expect(state.rounds == 4)
        #expect(!state.isPaused)
        // The rest of the schedule travels with it, so the lock screen can roll
        // over a boundary the app is asleep for.
        #expect(!state.upcoming.isEmpty)
    }

    @Test("A held interval has a card, and the card says it is held")
    func aHeldIntervalIsMarkedHeld() throws {
        var timer = IntervalTimer(focusMinutes: 25, breakMinutes: 5, rounds: 4)
        timer.start(at: now)
        timer.pause(at: now.addingTimeInterval(300))

        let instant = now.addingTimeInterval(600)
        let state = try #require(card(timer, at: instant))

        #expect(state.isPaused)
        #expect(state.pausedAt == instant)
        #expect(state.block == .focus)
    }

    @Test("Stopping an interval takes the card away")
    func stoppingAnIntervalEndsTheCard() {
        var timer = IntervalTimer(focusMinutes: 25, breakMinutes: 5, rounds: 4)
        timer.start(at: now)
        // Stop is only offered while the run is held, which is how the page
        // draws the row, so this is the sequence a user can actually perform.
        timer.pause(at: now.addingTimeInterval(300))
        timer.reset()

        #expect(card(timer, at: now.addingTimeInterval(400)) == nil)
    }

    @Test("An interval that reaches the end of its schedule takes the card away")
    func aFinishedIntervalEndsTheCard() {
        var timer = IntervalTimer(focusMinutes: 1, breakMinutes: 1, rounds: 2)
        timer.start(at: now)

        // Focus, break, focus — three minutes, and no break after the last
        // round.
        let afterTheEnd = now.addingTimeInterval(181)
        #expect(timer.snapshot(at: afterTheEnd).phase == .finished)
        #expect(card(timer, at: afterTheEnd) == nil)
    }

    @Test("Skipping the last break moves the card to the last focus block, which has nothing after it")
    func skippingTheLastBreakLandsOnTheLastBlock() throws {
        // Two rounds, so the run's only break is also its last one. It is
        // followed by the final focus block rather than by the end: a run never
        // finishes on a break, which is why Skip cannot end one either.
        var timer = IntervalTimer(focusMinutes: 1, breakMinutes: 1, rounds: 2)
        timer.start(at: now)

        let inTheBreak = now.addingTimeInterval(70)
        #expect(timer.snapshot(at: inTheBreak).blockKind == .break)
        #expect(timer.snapshot(at: inTheBreak).canSkip)

        timer.skip(at: inTheBreak)

        let state = try #require(card(timer, at: inTheBreak))

        #expect(state.block == .focus)
        #expect(state.round == 2)
        // Nothing follows the last focus block, so there is no boundary for the
        // lock screen to roll over on its own.
        #expect(state.upcoming.isEmpty)

        // And the run skipped into still ends the card when it runs out.
        #expect(card(timer, at: inTheBreak.addingTimeInterval(61)) == nil)
    }

    @Test("Skipping a break that is not the last one keeps the card, on the next block")
    func skippingAnEarlierBreakKeepsTheCard() throws {
        var timer = IntervalTimer(focusMinutes: 1, breakMinutes: 1, rounds: 3)
        timer.start(at: now)

        let inTheBreak = now.addingTimeInterval(70)
        timer.skip(at: inTheBreak)

        let state = try #require(card(timer, at: inTheBreak))

        #expect(state.block == .focus)
        #expect(state.round == 2)
        #expect(!state.upcoming.isEmpty)
    }

    @Test("Every phase the interval can be in has an answer", arguments: IntervalTimer.Phase.allCases)
    func everyIntervalPhaseIsAnswered(phase: IntervalTimer.Phase) {
        var timer = IntervalTimer(focusMinutes: 1, breakMinutes: 1, rounds: 2)
        var instant = now.addingTimeInterval(30)

        switch phase {
        case .setup:
            break
        case .running:
            timer.start(at: now)
        case .paused:
            timer.start(at: now)
            timer.pause(at: now.addingTimeInterval(10))
        case .finished:
            timer.start(at: now)
            instant = now.addingTimeInterval(181)
        }

        #expect(timer.snapshot(at: instant).phase == phase)

        let wantsACard = phase == .running || phase == .paused
        #expect((card(timer, at: instant) != nil) == wantsACard)
    }
}
