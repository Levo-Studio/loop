import Foundation

// MARK: - Scale detents

/// The values a `ScaleSlider` is allowed to stop on, handed to it by its screen.
///
/// The scale draws detents and snaps to them; it does not decide which ones
/// exist. Which durations are selectable is a rule about the timer — one-minute
/// steps up to two hours, five-minute steps beyond — and rules about the timer
/// live in `Loop/Engine/`, where a test can reach them without a simulator. This
/// type is only the shape the drawing needs, so the design layer never grows a
/// second opinion about the range.
///
/// Three questions, because a scale asks exactly three: what is under the
/// marker now, and what is one step either side of it for VoiceOver.
nonisolated struct ScaleDetents: Sendable {

    /// The first and last selectable value, in whole minutes. The scale draws
    /// nothing outside it, which is what gives the fixed centre marker its half
    /// screen of blank beyond either end.
    let range: ClosedRange<Int>

    private let nearestValue: @Sendable (Double) -> Int
    private let nextValue: @Sendable (Int) -> Int
    private let previousValue: @Sendable (Int) -> Int

    init(
        range: ClosedRange<Int>,
        nearest: @escaping @Sendable (Double) -> Int,
        next: @escaping @Sendable (Int) -> Int,
        previous: @escaping @Sendable (Int) -> Int
    ) {
        self.range = range
        self.nearestValue = nearest
        self.nextValue = next
        self.previousValue = previous
    }

    // MARK: - Asking

    /// The selectable value closest to an arbitrary position on the scale.
    ///
    /// Takes a `Double` because the finger is between detents for all but an
    /// instant of a drag, and rounding at the call site would round twice — once
    /// to a minute and again to a detent — which loses the half-step that
    /// decides which detent it is.
    func nearest(to minutes: Double) -> Int {
        let bounded = min(Double(range.upperBound), max(Double(range.lowerBound), minutes))
        return clamped(nearestValue(bounded))
    }

    /// The next detent above `value`, or `value` itself at the top of the range.
    func next(after value: Int) -> Int {
        clamped(nextValue(clamped(value)))
    }

    /// The next detent below `value`, or `value` itself at the bottom.
    func previous(before value: Int) -> Int {
        clamped(previousValue(clamped(value)))
    }

    /// Clamped on the way out as well as on the way in. A staged rule computes
    /// a step from the value it is given, and a value one past the end would
    /// otherwise be answered with a detent the scale does not draw.
    private func clamped(_ value: Int) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }

    // MARK: - Every minute

    /// A detent on every minute from zero to `maximum`.
    ///
    /// Not a staged rule and not a fallback for one — it is the plain
    /// arithmetic case, and it is what a scale means before anyone asks it to
    /// run for thirty hours.
    static func everyMinute(through maximum: Int) -> ScaleDetents {
        let upper = max(0, maximum)
        return ScaleDetents(
            range: 0...upper,
            nearest: { Int($0.rounded()) },
            next: { $0 + 1 },
            previous: { $0 - 1 }
        )
    }
}
