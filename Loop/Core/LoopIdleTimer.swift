import Foundation

// MARK: - Idle timer

/// Whether the display is allowed to go to sleep, given what the three timers
/// are doing.
///
/// A value rather than a line inside a view, for the same reason `LoopDismissal`
/// is one: it is a rule with a wrong answer, so it is somewhere a test can ask
/// it. The view is left with one assignment.
///
/// **Turning it on is easy; the bug is leaving it on.** A screen held awake
/// after the run that justified it has ended burns the battery of a device
/// sitting face up on a desk, and nobody reports it because nothing looks
/// broken. So the answer is derived from the state at an instant and carries
/// how long it holds — the caller wakes when it expires and asks again, rather
/// than trusting that something will come along to switch it off.
nonisolated enum LoopIdleTimer {

    // MARK: - The answer

    struct Decision: Sendable, Equatable {

        /// What `isIdleTimerDisabled` is set to.
        let keepsDisplayAwake: Bool

        /// How long this answer holds if nobody touches anything.
        ///
        /// The remaining time of whichever running block ends first — for the
        /// interval that is the current block rather than the whole run, so the
        /// answer is re-taken at every boundary and stays true if the run ends
        /// there. `nil` means no clock can change it: with nothing running,
        /// only a tap can, and a tap changes the state the answer is taken
        /// from.
        let holdsFor: TimeInterval?
    }

    // MARK: - The rule

    /// The display stays on while a countdown or an interval is **running**, and
    /// goes to sleep in every other state: paused, finished, in setup, and on
    /// the clock and settings pages, which have no run at all.
    ///
    /// It is asked of all three timers at once rather than of the page on
    /// screen. A countdown does not stop being the reason to keep the screen
    /// alive because the user swiped over to the clock, and the finished state
    /// stops being one whether or not anybody is looking at it.
    ///
    /// **The stopwatch deliberately does not count**, and this is the one place
    /// the rule is narrower than the design notes, which say the screen stays on
    /// "as long as a timer runs". The other two run towards
    /// a moment: the number on screen is worth reading precisely because it is
    /// about to reach zero, and a display that has gone dark by then has failed
    /// at the one job. A count-up has no such moment — it is started and left,
    /// often for a whole session, and holding a phone's screen on for an hour
    /// against a run that never ends is exactly the "left on" failure this type
    /// exists to avoid. Nothing is lost by letting it sleep: the elapsed time
    /// comes from a stored instant, so it is right the moment the screen comes
    /// back, and a tap is enough to look.
    static func decision(for state: LoopTimerState, at now: Date) -> Decision {
        let countdown = state.countdown.snapshot(at: now)
        let interval = state.interval.snapshot(at: now)

        var running: [TimeInterval] = []
        if countdown.phase == .running { running.append(countdown.remaining) }
        if interval.phase == .running { running.append(interval.remaining) }

        guard let soonest = running.min() else {
            return Decision(keepsDisplayAwake: false, holdsFor: nil)
        }

        return Decision(keepsDisplayAwake: true, holdsFor: soonest)
    }
}
