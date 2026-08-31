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
          "countdown": { "durationMinutes": 9000, "storedPhase": "idle", "tracker": { "accumulated": 0 } },
          "interval": {
            "focusMinutes": 9000, "breakMinutes": -4, "rounds": 0,
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
        #expect(state.interval.focusMinutes == 8 * 60)
        #expect(state.interval.breakMinutes == 0)
        #expect(state.countdown.durationMinutes == 30 * 60)
        #expect(state.countUp.elapsed(at: start) == 0)

        // And the schedule the clamped record produces is readable rather than
        // fatal.
        #expect(state.interval.schedule.count == 1)
        #expect(state.interval.snapshot(at: start).round == 1)
        #expect(state.interval.snapshot(at: start).blockKind == .focus)
    }

    @Test("A stored value between two detents is resolved, not rejected")
    func offDetentRecordIsSnapped() {
        // The scales were not always staged, so a perfectly legal older record
        // can hold a value that no longer sits on a detent. Falling back to the
        // default would throw away what the user set; snapping keeps it.
        let record = """
        {
          "countUp": { "tracker": { "accumulated": 0 } },
          "countdown": { "durationMinutes": 123, "storedPhase": "idle", "tracker": { "accumulated": 0 } },
          "interval": {
            "focusMinutes": 122, "breakMinutes": 7, "rounds": 4,
            "storedPhase": "setup", "tracker": { "accumulated": 0 }
          }
        }
        """

        let state = Self.load(record, at: start)

        #expect(state.countdown.durationMinutes == 125)
        #expect(state.interval.focusMinutes == 120)

        // Below two hours nothing moves: every minute is still a detent, and a
        // break is on one-minute steps over its whole length.
        #expect(state.interval.breakMinutes == 7)
    }

    @Test("A stopwatch record with no start instant cannot come back half running")
    func countUpWithoutAStartInstant() {
        // The type cannot express "running with nothing to say since when", but
        // a record can: decoding assigns the properties one by one. Left alone,
        // the page would report a running run whose "since 09:29" line had
        // nothing to name.
        let running = """
        {
          "countUp": { "tracker": { "accumulated": 0, "startedAt": 100 } },
          "countdown": { "durationMinutes": 25, "storedPhase": "idle", "tracker": { "accumulated": 0 } },
          "interval": {
            "focusMinutes": 25, "breakMinutes": 5, "rounds": 4,
            "storedPhase": "setup", "tracker": { "accumulated": 0 }
          }
        }
        """

        let recovered = Self.load(running, at: start)
        #expect(recovered.countUp.phase(at: start) == .running)

        // The tracker's own instant is the run's instant — there is no other
        // candidate, and it is the truthful one.
        #expect(recovered.countUp.startDate == Date(timeIntervalSinceReferenceDate: 100))
        #expect(recovered.countUp.snapshot(at: start).startDate != nil)

        // With no instant anywhere, banked time is time the page cannot account
        // for, so the run does not exist.
        let banked = running.replacingOccurrences(
            of: "\"accumulated\": 0, \"startedAt\": 100",
            with: "\"accumulated\": 600"
        )
        let reset = Self.load(banked, at: start)
        #expect(reset.countUp.phase(at: start) == .idle)
        #expect(reset.countUp.elapsed(at: start) == 0)
        #expect(reset.countUp.startDate == nil)
    }

    private static func load(_ record: String, at now: Date) -> LoopTimerState {
        let defaults = UserDefaults(suiteName: "loop.tests.\(UUID().uuidString)") ?? .standard
        let key = "loop.timers.state"
        defaults.set(Data(record.utf8), forKey: key)
        return TimerStateStore(defaults: defaults, key: key).load(at: now)
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
