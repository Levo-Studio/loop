import Foundation

// MARK: - Limits

/// The ranges the sliders and the stepper can produce, in one place.
///
/// The screens clamp what they hand in, but the engine clamps again: a value
/// that arrives out of range is a bug somewhere, and the timer that has to
/// survive a restart is the wrong place to find out. Clamping rather than
/// trapping keeps a corrupted stored state loadable instead of crashing the app
/// on launch.
nonisolated enum LoopTimerLimits {

    /// Countdown duration and interval focus block, whole minutes.
    static let durationMinutes = 0...60

    /// Interval break block, whole minutes. Shorter scale than the focus one.
    static let breakMinutes = 0...30

    /// Interval rounds. One round is a single focus block with no break after
    /// it, which is the smallest run that still means something.
    static let rounds = 1...99

    static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
