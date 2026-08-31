import Foundation
import Observation

// MARK: - Timers

/// The three timers, owned once for the whole app and written to disk whenever
/// one of them changes.
///
/// **One owner, one record.** The pages are swiped between and any of them can
/// be running when the app goes away, so a timer that lived on its screen would
/// be a timer that only the screen it belongs to could save — five screens each
/// persisting themselves, five chances for one of them to forget. The record on
/// disk is a single `LoopTimerState` for the same reason: there is no moment at
/// which only one of the three is worth writing.
///
/// It also puts the running state of every page in one place, which is what
/// lets the shell answer a question no single screen can — whether anything at
/// all is counting, and therefore whether the display is allowed to go to
/// sleep.
///
/// This is `Core/` rather than `Engine/` on the line the architecture draws:
/// everything that can go wrong about a timer is in the values it holds, and
/// those are engine types with their own tests. What is left here is the
/// ownership — an `@Observable` box that reads at launch, hands the current
/// value to the views, and writes after a change.
@Observable
final class LoopTimers {

    // MARK: - State

    /// The three timers as they stand. Read-only from outside: every change
    /// goes through `update(_:_:)`, so there is one place a write to disk can
    /// be missed and it is not spread over the screens.
    private(set) var state: LoopTimerState

    /// Excluded from observation because it is not drawn and never changes —
    /// tracking it would invalidate views for a value no view reads.
    @ObservationIgnored private let store: TimerStateStore

    // MARK: - The three timers

    /// Conveniences for the screens, which each read exactly one of the three.
    var countUp: CountUpTimer { state.countUp }

    var countdown: CountdownTimer { state.countdown }

    var interval: IntervalTimer { state.interval }

    // MARK: - Life cycle

    /// Reads the stored record and brings it up to `now` before anything is
    /// drawn from it.
    ///
    /// A countdown that ran out while the app was gone is already finished by
    /// the time the first frame is built, so no page has to draw a run that the
    /// clock says is over — which is the whole reason the state is stored as an
    /// instant rather than as a count.
    init(store: TimerStateStore = TimerStateStore(), now: Date = .now) {
        self.store = store
        state = store.load(at: now)
    }

    // MARK: - Changing

    /// Applies a change to one of the three timers and writes the result out.
    ///
    /// **Nothing is written when nothing moved.** A running screen commits its
    /// transitions on every tick, and all but one of those ticks resolve to the
    /// value the timer already held; comparing first turns a write a second
    /// into a write per state change, and keeps the views from being
    /// invalidated for a value that did not move.
    func update<Timer: Equatable>(
        _ timer: WritableKeyPath<LoopTimerState, Timer>,
        _ change: (inout Timer) -> Void
    ) {
        var changed = state
        change(&changed[keyPath: timer])
        guard changed != state else { return }

        state = changed
        store.save(changed)
    }
}
