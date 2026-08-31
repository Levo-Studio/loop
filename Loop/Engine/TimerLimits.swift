import Foundation

// MARK: - Limits

/// How far each scale runs and which values on it can be picked, in one place.
///
/// The screens resolve what they hand in, but the engine resolves again: a
/// value that arrives out of range or between two detents is a bug somewhere,
/// and the timer that has to survive a restart is the wrong place to find out.
/// Resolving rather than trapping keeps a corrupted stored state loadable
/// instead of crashing the app on launch, and resolving rather than rejecting
/// means a record written by an older build — whose 63 minutes was a legal
/// value then — comes back as the nearest value that is legal now instead of
/// as a default that silently discards what the user set.
nonisolated enum LoopTimerLimits {

    // MARK: - Steps

    /// One minute up to two hours, five minutes beyond it.
    ///
    /// The scales scroll, so the length of a scale costs nothing but the number
    /// of detents on it does. Two hours is where a duration stops being chosen
    /// to the minute and starts being chosen to the nearest five — nobody sets
    /// a nine-hour countdown and cares about the second digit — and it keeps
    /// every value people actually pick, up to and including a two-hour block,
    /// exactly reachable.
    ///
    /// Shared by all three minute scales. The break never reaches the second
    /// stage (see below), which is deliberate rather than an oversight: a break
    /// is adjustable to the minute over its whole length.
    static let stages: [LoopMinuteScale.Stage] = [
        .init(start: 0, step: 1),
        .init(start: 2 * 60, step: 5)
    ]

    // MARK: - Scales

    /// The countdown's duration, and its only control. **Thirty hours.**
    ///
    /// A countdown is one uninterrupted block with nothing multiplying it, so
    /// the upper bound is the one the owner set and no argument narrows it: a
    /// long stretch — an overnight run, a deadline the far side of a night's
    /// sleep — is a single duration and this is the screen for it. Zero stays
    /// reachable and is refused at `start` instead, so the scale has no
    /// unreachable end.
    static let duration = LoopMinuteScale(range: 0...(30 * 60), stages: stages)

    /// The interval's focus block. **Eight hours**, narrower than the
    /// countdown.
    ///
    /// A focus block is not a duration, it is a duration multiplied by up to 99
    /// rounds: thirty hours here would offer a run of 124 days, a number no
    /// setup screen can mean and no session can finish. Eight hours is a full
    /// working day *as a single unbroken block*, which is already past the
    /// point where an interval timer is what someone needs — beyond it the
    /// answer is the countdown, not more rounds. It also sits on the
    /// five-minute grid, so the end of the scale is reachable.
    static let focus = LoopMinuteScale(range: 0...(8 * 60), stages: stages)

    /// The interval's break block. **Two hours**, narrower again.
    ///
    /// A pause longer than the focus block it follows is not a break, it is the
    /// end of the session, and a timer that offers a thirty-hour break offers
    /// nonsense next to the value it is meant to be read against. Two hours is
    /// where the step scale changes anyway, so the break is the one scale that
    /// stays on one-minute detents from end to end — which is the right
    /// trade for a value that is usually set between three and fifteen minutes.
    static let breakLength = LoopMinuteScale(range: 0...(2 * 60), stages: stages)

    /// Interval rounds. **Unchanged at 1…99.**
    ///
    /// One round is a single focus block with no break after it, which is the
    /// smallest run that still means something. The upper bound is not a
    /// judgement about session length but about the counter the design draws:
    /// "Focus · Round 02 / 04" is two digits, and a hundredth round has nowhere
    /// to be rendered. Rounds are counted rather than dialled, so they have no
    /// staging — every whole number in the range is selectable.
    static let rounds = 1...99

    // MARK: - Bounds

    /// The ends of the scales, for the call sites that need only the ends and
    /// not the detents between them. One source of truth: the scale.
    static var durationMinutes: ClosedRange<Int> { duration.range }

    static var focusMinutes: ClosedRange<Int> { focus.range }

    static var breakMinutes: ClosedRange<Int> { breakLength.range }

    static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
