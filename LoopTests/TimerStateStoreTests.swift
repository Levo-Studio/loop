import Testing
import Foundation

@testable import Loop

// MARK: - Persistence

@Suite("Timer persistence")
struct TimerStateStoreTests {

    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    /// A throwaway suite per test, so no run touches the app's real defaults
    /// and no test can read what another one wrote.
    private func makeStore() -> TimerStateStore {
        let suiteName = "loop.tests.\(UUID().uuidString)"
        return TimerStateStore(defaults: UserDefaults(suiteName: suiteName) ?? .standard)
    }

    @Test("Nothing stored gives fresh timers")
    func emptyStore() {
        let state = makeStore().load(at: start)

        #expect(state.countdown.phase(at: start) == .idle)
        #expect(state.interval.phase(at: start) == .setup)
        #expect(state.countUp.phase(at: start) == .idle)
    }

    @Test("A running countdown keeps counting across a restart")
    func runningCountdownSurvives() {
        let store = makeStore()

        var state = LoopTimerState()
        state.countdown = CountdownTimer(durationMinutes: 25)
        state.countdown.start(at: start)
        store.save(state)

        // Ten minutes later the app comes back: still running, still counting
        // from the instant it was started.
        let restored = store.load(at: start.addingTimeInterval(600))
        #expect(restored.countdown.phase(at: start.addingTimeInterval(600)) == .running)
        #expect(restored.countdown.remaining(at: start.addingTimeInterval(600)) == 900)
    }

    @Test("A countdown whose duration ran out while the app was gone is finished")
    func countdownFinishesWhileAway() {
        let store = makeStore()

        var state = LoopTimerState()
        state.countdown = CountdownTimer(durationMinutes: 25)
        state.countdown.start(at: start)
        store.save(state)

        // Two hours in the background. The stored instant is what makes this
        // answerable at all.
        let restored = store.load(at: start.addingTimeInterval(2 * 3_600))
        #expect(restored.countdown.phase(at: start) == .finished)
        #expect(restored.countdown.remaining(at: start.addingTimeInterval(2 * 3_600)) == 0)
    }

    @Test("An interval left running overnight comes back finished")
    func intervalFinishesOvernight() {
        let store = makeStore()

        var state = LoopTimerState()
        state.interval = IntervalTimer(focusMinutes: 25, breakMinutes: 5, rounds: 4)
        state.interval.start(at: start)
        store.save(state)

        let restored = store.load(at: start.addingTimeInterval(8 * 3_600))
        #expect(restored.interval.phase(at: start) == .finished)
    }

    @Test("An interval comes back on the block its schedule reached")
    func intervalRestoresMidRun() {
        let store = makeStore()

        var state = LoopTimerState()
        state.interval = IntervalTimer(focusMinutes: 25, breakMinutes: 5, rounds: 4)
        state.interval.start(at: start)
        store.save(state)

        let now = start.addingTimeInterval(3_500)
        let restored = store.load(at: now)
        #expect(restored.interval.phase(at: now) == .running)
        #expect(restored.interval.currentBlock(at: now)?.kind == .break)
        #expect(restored.interval.currentBlock(at: now)?.round == 2)
    }

    @Test("A paused timer comes back paused, however long it was away")
    func pausedSurvives() {
        let store = makeStore()

        var state = LoopTimerState()
        state.interval = IntervalTimer(focusMinutes: 25, breakMinutes: 5, rounds: 4)
        state.interval.start(at: start)
        state.interval.pause(at: start.addingTimeInterval(600))
        store.save(state)

        let now = start.addingTimeInterval(8 * 3_600)
        let restored = store.load(at: now)
        #expect(restored.interval.phase(at: now) == .paused)
        #expect(restored.interval.remaining(at: now) == 900)
    }

    @Test("The setup values survive even with no run going")
    func setupSurvives() {
        let store = makeStore()

        var state = LoopTimerState()
        state.interval = IntervalTimer(focusMinutes: 40, breakMinutes: 12, rounds: 7)
        state.countdown = CountdownTimer(durationMinutes: 45)
        store.save(state)

        let restored = store.load(at: start)
        #expect(restored.interval.focusMinutes == 40)
        #expect(restored.interval.breakMinutes == 12)
        #expect(restored.interval.rounds == 7)
        #expect(restored.countdown.durationMinutes == 45)
    }

    @Test("A record that cannot be read gives fresh timers rather than an error")
    func unreadableRecord() {
        let suiteName = "loop.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let key = "loop.timers.state"
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: key)

        let store = TimerStateStore(defaults: defaults, key: key)
        #expect(store.load(at: start).countdown.phase(at: start) == .idle)
    }

    @Test("Values outside the ranges are clamped on the way back in")
    func corruptRecordIsClamped() {
        // A record written by an older build, or by a bug. Decoding bypasses
        // the initialisers, so this is the only path that would let rounds = 0
        // reach the schedule — where 1...0 traps, on the launch path.
        let record = """
        {
          "countUp": { "tracker": { "accumulated": -5 } },
          "countdown": { "durationMinutes": 900, "storedPhase": "idle", "tracker": { "accumulated": 0 } },
          "interval": {
            "focusMinutes": 900, "breakMinutes": -4, "rounds": 0,
            "storedPhase": "running", "tracker": { "accumulated": -10 }
          }
        }
        """

        let suiteName = "loop.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let key = "loop.timers.state"
        defaults.set(Data(record.utf8), forKey: key)

        let state = TimerStateStore(defaults: defaults, key: key).load(at: start)

        #expect(state.interval.rounds == 1)
        #expect(state.interval.focusMinutes == 60)
        #expect(state.interval.breakMinutes == 0)
        #expect(state.countdown.durationMinutes == 60)
        #expect(state.countUp.elapsed(at: start) == 0)

        // And the schedule the clamped record produces is readable rather than
        // fatal.
        #expect(state.interval.schedule.count == 1)
        #expect(state.interval.snapshot(at: start).round == 1)
        #expect(state.interval.snapshot(at: start).blockKind == .focus)
    }

    @Test("Clearing the record puts the pages back to their setup state")
    func clear() {
        let store = makeStore()

        var state = LoopTimerState()
        state.countdown = CountdownTimer(durationMinutes: 45)
        store.save(state)
        store.clear()

        #expect(store.load(at: start).countdown.durationMinutes == 25)
    }
}
