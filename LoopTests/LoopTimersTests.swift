import Testing
import Foundation

@testable import Loop

// MARK: - Ownership

/// The round trip the app actually makes: a run started through the owner is on
/// disk, and a second owner over the same store is the app coming back.
///
/// On the main actor because the owner is — it is the app's state, read by
/// views. The values it carries are engine types and are tested there.
@MainActor
@Suite("Timer ownership")
struct LoopTimersTests {

    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    /// A throwaway suite per test, so no run touches the app's real defaults
    /// and no test can read what another one wrote.
    private func makeStore() -> TimerStateStore {
        TimerStateStore(defaults: UserDefaults(suiteName: "loop.tests.\(UUID().uuidString)") ?? .standard)
    }

    @Test("A countdown started through the owner is still running after a relaunch")
    func countdownSurvivesRelaunch() {
        let store = makeStore()

        let timers = LoopTimers(store: store, now: start)
        timers.update(\.countdown) { $0.setDuration(minutes: 25, at: start) }
        timers.update(\.countdown) { $0.start(at: start) }

        let relaunched = LoopTimers(store: store, now: start.addingTimeInterval(600))
        #expect(relaunched.countdown.phase(at: start.addingTimeInterval(600)) == .running)
        #expect(relaunched.countdown.remaining(at: start.addingTimeInterval(600)) == 900)
    }

    @Test("A run that ran out while the app was gone comes back finished")
    func countdownFinishesWhileAway() {
        let store = makeStore()

        let timers = LoopTimers(store: store, now: start)
        timers.update(\.countdown) { $0.start(at: start) }

        // The owner resolves the record on the way in, so the first frame the
        // app draws is already the finished one rather than a run being
        // corrected a tick later.
        let relaunched = LoopTimers(store: store, now: start.addingTimeInterval(2 * 3_600))
        #expect(relaunched.countdown.phase(at: start) == .finished)
    }

    @Test("The three timers are one record: writing one keeps the other two")
    func oneRecord() {
        let store = makeStore()

        let timers = LoopTimers(store: store, now: start)
        timers.update(\.interval) { $0.setFocusMinutes(40, at: start) }
        timers.update(\.countdown) { $0.setDuration(minutes: 45, at: start) }
        timers.update(\.countUp) { $0.start(at: start) }

        let relaunched = LoopTimers(store: store, now: start.addingTimeInterval(60))
        #expect(relaunched.interval.focusMinutes == 40)
        #expect(relaunched.countdown.durationMinutes == 45)
        #expect(relaunched.countUp.phase(at: start) == .running)
        #expect(relaunched.countUp.elapsed(at: start.addingTimeInterval(60)) == 60)
    }

    @Test("A stopwatch that was on hold comes back on hold, with its time intact")
    func pausedStopwatchSurvives() {
        let store = makeStore()

        let timers = LoopTimers(store: store, now: start)
        timers.update(\.countUp) { $0.start(at: start) }
        timers.update(\.countUp) { $0.pause(at: start.addingTimeInterval(90)) }

        let relaunched = LoopTimers(store: store, now: start.addingTimeInterval(8 * 3_600))
        #expect(relaunched.countUp.phase(at: start) == .paused)
        #expect(relaunched.countUp.elapsed(at: start.addingTimeInterval(8 * 3_600)) == 90)
    }

    @Test("A change that moves nothing writes nothing")
    func unchangedStateIsNotWritten() {
        let store = makeStore()
        let timers = LoopTimers(store: store, now: start)

        // Written behind the owner's back, so the record on disk and the one in
        // memory differ. A no-op update that still wrote would overwrite this;
        // one that compares first leaves it alone.
        var marker = LoopTimerState()
        marker.countdown = CountdownTimer(durationMinutes: 45)
        store.save(marker)

        // What a running page does on every tick: a countdown that is idle
        // resolves to exactly the value it already held.
        timers.update(\.countdown) { $0.commitTransitions(at: start) }

        #expect(store.load(at: start).countdown.durationMinutes == 45)
    }

    @Test("Nothing stored is the first launch, not an error")
    func firstLaunch() {
        let timers = LoopTimers(store: makeStore(), now: start)

        #expect(timers.countUp.phase(at: start) == .idle)
        #expect(timers.countdown.phase(at: start) == .idle)
        #expect(timers.interval.phase(at: start) == .setup)
    }
}
