import ActivityKit
import Foundation

// MARK: - Live Activity controller

/// Starts, updates and ends Loop's Live Activity.
///
/// One controller rather than one per screen. Only one Activity may be on the
/// lock screen at a time — a countdown and an interval running together would
/// otherwise stack two cards that disagree — and holding the handle in one place
/// is what lets a second screen's run replace the first's rather than add to it.
///
/// The controller derives everything from the snapshot the screen is already
/// drawing. It never reads a timer itself and never keeps a clock: a second
/// model of the run beside the one on screen is a second chance to be wrong, and
/// the one nobody looks at is the one that drifts.
@MainActor
final class LoopActivityController {

    /// The screens reach the same instance; see the note above on why there is
    /// only one.
    static let shared = LoopActivityController()

    private var activity: Activity<LoopActivityAttributes>?

    /// The state as last handed to ActivityKit, so an update that would change
    /// nothing is never sent. See `hasMoved(from:to:)`.
    private var pushed: LoopActivityAttributes.ContentState?

    /// Set when a request was refused, and cleared when the run ends.
    ///
    /// `apply` is called on the screen's tick, so without this a request that
    /// throws — Live Activities switched off, the per-app limit reached, a
    /// state over budget — would be retried once a second for the length of the
    /// run. The answer will not have changed by the next tick, and the run that
    /// failed to start one is not the run that should keep asking.
    private var isRefused = false

    // MARK: - Countdown

    /// Brings the Live Activity in line with a countdown frame.
    ///
    /// Safe to call on every tick: an idle or finished countdown ends the
    /// Activity, and a running one only reaches ActivityKit when something the
    /// lock screen draws has actually moved.
    func update(countdown snapshot: CountdownTimer.Snapshot, accent: LoopAccent, at now: Date) {
        switch snapshot.phase {
        case .idle, .finished:
            end()

        case .running, .paused:
            apply(
                LoopActivityAttributes.ContentState(
                    block: .countdown,
                    round: 1,
                    rounds: 1,
                    window: Self.window(remaining: snapshot.remaining, duration: snapshot.duration, at: now),
                    pausedAt: snapshot.phase == .paused ? now : nil,
                    accentID: accent.rawValue,
                    // A countdown is one block. There is nothing after it, so
                    // there is no boundary it could be asleep through.
                    upcoming: []
                )
            )
        }
    }

    // MARK: - Interval

    /// Brings the Live Activity in line with an interval frame. Same contract as
    /// the countdown's: call it on the tick and it does the right nothing.
    func update(interval snapshot: IntervalTimer.Snapshot, accent: LoopAccent, at now: Date) {
        switch snapshot.phase {
        case .setup, .finished:
            end()

        case .running, .paused:
            let window = Self.window(remaining: snapshot.remaining, duration: snapshot.blockDuration, at: now)

            apply(
                LoopActivityAttributes.ContentState(
                    block: snapshot.blockKind == .focus ? .focus : .rest,
                    round: snapshot.round,
                    rounds: snapshot.rounds,
                    window: window,
                    pausedAt: snapshot.phase == .paused ? now : nil,
                    accentID: accent.rawValue,
                    upcoming: Self.upcoming(after: snapshot, endingAt: window.upperBound)
                )
            )
        }
    }

    // MARK: - The rest of the schedule

    /// How many blocks past the current one the state carries.
    ///
    /// The bound is the content state's own budget: ActivityKit caps it at
    /// 4 KB, and a block encodes as a kind, a round and two dates — on the order
    /// of a hundred bytes. Twenty-four leaves the encoded state comfortably
    /// inside the cap with the rest of the fields, and `LoopActivityStateTests`
    /// encodes a fully loaded state and asserts it.
    ///
    /// It is a bound rather than the whole schedule because rounds go to 99,
    /// which is 197 blocks and several times the budget. Twenty-four covers a
    /// twelve-round run outright, and any longer run for its first
    /// twenty-four boundaries — far past the eight hours ActivityKit gives the
    /// Activity anyway.
    nonisolated static let maxUpcomingBlocks = 24

    /// The blocks that follow the one the snapshot is in, in order.
    ///
    /// This walks the same rule as `IntervalTimer.schedule` — focus, break,
    /// focus, break, and no break after the final round — from the three scales
    /// the snapshot carries, because a snapshot is one frame and does not hand
    /// out the schedule around it. Two readings of one rule is exactly the
    /// duplication this project does not want, so `LoopActivityBoundaryTests`
    /// checks this against `IntervalTimer.schedule` itself, block for block, for
    /// a range of configurations. If the engine's shape ever changes, that test
    /// goes red rather than the lock screen going quietly wrong.
    nonisolated static func upcoming(
        after snapshot: IntervalTimer.Snapshot,
        endingAt blockEnd: Date
    ) -> [LoopActivityAttributes.Upcoming] {
        let focus = TimeInterval(snapshot.focusMinutes) * 60
        let rest = TimeInterval(snapshot.breakMinutes) * 60

        var blocks: [LoopActivityAttributes.Upcoming] = []
        var kind = snapshot.blockKind
        var round = snapshot.round
        var start = blockEnd

        while blocks.count < maxUpcomingBlocks {
            let next: (block: LoopActivityAttributes.Block, round: Int, duration: TimeInterval)?

            switch kind {
            case .focus where round >= snapshot.rounds:
                // The run ends on a focus block: there is no break after the
                // last round and nothing follows it.
                next = nil

            // A zero-minute break is legal and means focus blocks back to back.
            // The engine steps over a block that ends where it starts rather
            // than showing it for a frame, and so does this.
            case .focus where rest > 0:
                next = (.rest, round, rest)

            case .focus:
                next = (.focus, round + 1, focus)

            case .break:
                next = (.focus, round + 1, focus)
            }

            guard let next else { break }

            let end = start.addingTimeInterval(max(next.duration, 1))
            blocks.append(
                LoopActivityAttributes.Upcoming(block: next.block, round: next.round, window: start...end)
            )

            kind = next.block == .focus ? .focus : .break
            round = next.round
            start = end
        }

        return blocks
    }

    // MARK: - Ending

    /// Takes the Activity off the lock screen at once.
    ///
    /// `.immediate` rather than the default grace period: the run is over
    /// because the user stopped or finished it, and they are looking at the app
    /// while it happens. A card that outlives the screen it mirrors reads as one
    /// that is still running.
    func end() {
        guard let activity else { return }

        self.activity = nil
        pushed = nil
        isRefused = false

        enqueue { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    // MARK: - The window

    /// The wall-clock span of the block being counted.
    ///
    /// Derived from the snapshot's own `remaining` rather than from a stored
    /// end date, so the Activity cannot disagree with the screen: the same value
    /// that prints `12:34` decides when iOS stops counting.
    ///
    /// A held run gives the window it *would* run out in if it were resumed now,
    /// which is what makes a resume free — `pausedAt` freezes the digits where
    /// they are, and dropping it lets the same window run on from there.
    nonisolated static func window(remaining: TimeInterval, duration: TimeInterval, at now: Date) -> ClosedRange<Date> {
        let end = now.addingTimeInterval(remaining)

        // A zero-length block would give an empty range, which `ClosedRange`
        // accepts but `Text(timerInterval:)` has nothing to count inside. One
        // second is the smallest span that still reads as a block.
        let start = end.addingTimeInterval(-max(duration, 1))
        return start...end
    }

    // MARK: - Pushing

    private func apply(_ state: LoopActivityAttributes.ContentState) {
        guard let pushed else {
            guard !isRefused else { return }
            start(state)
            return
        }

        guard Self.hasMoved(from: pushed, to: state) else { return }

        self.pushed = state
        let content = Self.content(state)

        enqueue { [activity] in await activity?.update(content) }
    }

    // MARK: - Ordering

    /// The last handed-off piece of ActivityKit work, so the next one can wait
    /// for it.
    ///
    /// `Activity.update` and `Activity.end` are `async`, and unstructured tasks
    /// start in no particular order. A skip landing right behind a resume could
    /// otherwise be applied first, leaving the lock screen on the older frame
    /// while `pushed` insists the newer one was sent — and nothing would push
    /// again until the next boundary. Chaining them keeps the order the screen
    /// produced them in.
    private var pending: Task<Void, Never>?

    /// The work stays on the main actor, because `Activity` is not `Sendable`
    /// and the handle cannot cross to another one.
    private func enqueue(_ work: @escaping @MainActor () async -> Void) {
        let previous = pending
        pending = Task { @MainActor in
            await previous?.value
            await work()
        }
    }

    private func start(_ state: LoopActivityAttributes.ContentState) {
        // Live Activities are a per-app permission the user can withdraw in
        // Settings. Asking each time rather than caching the answer: it can
        // change while the app is running.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        activity = try? Activity.request(
            attributes: LoopActivityAttributes(),
            content: Self.content(state)
        )

        // Only record what was pushed if the request was taken. A failed
        // request that left `pushed` set would suppress every later update and
        // the lock screen would stay empty for the rest of the run.
        pushed = activity == nil ? nil : state
        isRefused = activity == nil
    }

    private static func content(
        _ state: LoopActivityAttributes.ContentState
    ) -> ActivityContent<LoopActivityAttributes.ContentState> {
        // The block's end is where the state stops being true: after it the
        // window has run out and the next update has not arrived. A held run has
        // no such instant, because frozen digits stay right for as long as they
        // are frozen.
        ActivityContent(state: state, staleDate: state.isPaused ? nil : state.window.upperBound)
    }

    // MARK: - When to push

    /// How far the end of the window may move before it is worth an update.
    ///
    /// This is the whole reason the Activity is not pushed every second. While a
    /// run is going, `remaining` shrinks exactly as fast as `now` grows, so the
    /// window the tick derives is the same window as a second ago to within the
    /// arithmetic. Anything under this is that arithmetic; anything over it is a
    /// pause, a resume, a skip or a block boundary, and those are the four
    /// moments the lock screen has something new to say.
    ///
    /// ActivityKit throttles frequent updates and drops the ones over budget, so
    /// a controller that pushed on every tick would not merely waste the budget —
    /// it would spend it on frames that look identical and have none left for
    /// the boundary that matters.
    nonisolated private static let windowTolerance: TimeInterval = 0.5

    nonisolated static func hasMoved(
        from old: LoopActivityAttributes.ContentState,
        to new: LoopActivityAttributes.ContentState
    ) -> Bool {
        if old.block != new.block { return true }
        if old.round != new.round || old.rounds != new.rounds { return true }
        if old.accentID != new.accentID { return true }
        if old.isPaused != new.isPaused { return true }

        // A held run is re-derived on every tick, and its window walks forward
        // with `now` because `remaining` is frozen. Nothing the lock screen
        // draws moves with it — the frozen digits are `end − pausedAt`, which is
        // that same `remaining` — so pushing it would be one update per second
        // for a frame that never changes. This is the line that keeps a paused
        // timer off the update budget.
        if old.isPaused, new.isPaused { return false }

        return abs(new.window.upperBound.timeIntervalSince(old.window.upperBound)) > windowTolerance
    }
}
