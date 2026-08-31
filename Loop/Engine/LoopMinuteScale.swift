import Foundation

// MARK: - Minute scale

/// The selectable minute values of a scale, and the questions a picker asks
/// about them.
///
/// The scales scroll under a fixed centre marker, so how far one runs is no
/// longer bounded by what fits across the screen. That makes the step size the
/// real constraint: thirty hours in one-minute detents is 1800 of them to drag
/// past, and a single coarse step everywhere would take the minute away from
/// the values people actually pick. So the step grows with the value — fine
/// where the choices are, coarse where the distance is.
///
/// The staging is data rather than a pair of constants inside an `if`. A third
/// stage — say fifteen minutes beyond a day — is one more entry in `stages`,
/// and nothing that asks this type a question has to change.
nonisolated struct LoopMinuteScale: Sendable, Equatable {

    // MARK: - Stage

    /// "From `start` minutes on, the selectable values are every `step`
    /// minutes, counted from `start`."
    ///
    /// A stage's `start` is expected to sit on the grid of the stage below it,
    /// which is what makes a boundary reachable from both directions: 120 is a
    /// multiple of one minute, so walking up in minutes lands on it exactly and
    /// the five-minute stage takes over from there.
    struct Stage: Sendable, Equatable {
        let start: Int
        let step: Int
    }

    // MARK: - Shape

    /// The ends of the scale. Both ends are meant to be selectable values —
    /// an upper bound that is not on a detent could never be reached, and the
    /// end of a scale is the one value a user is most likely to drag for.
    let range: ClosedRange<Int>

    /// Ordered by `start`, coarsest last.
    let stages: [Stage]

    /// The preconditions guard constants, not stored data: scales are built
    /// from literals in `LoopTimerLimits`, never decoded. An empty stage list
    /// or a zero step would divide by zero on the first question asked, so
    /// failing here fails on the first launch of a wrong build rather than in
    /// someone's hands.
    init(range: ClosedRange<Int>, stages: [Stage]) {
        precondition(!stages.isEmpty, "A minute scale needs at least one stage.")
        precondition(stages.allSatisfy { $0.step > 0 }, "A stage without a positive step has no detents.")

        self.range = range
        self.stages = stages.sorted { $0.start < $1.start }
    }

    // MARK: - Asking

    /// Whether this exact value is one the scale can come to rest on.
    ///
    /// Out of range counts as not selectable: a value the scale cannot show is
    /// not a detent, even if the arithmetic would agree.
    func isSelectable(_ minutes: Int) -> Bool {
        guard range.contains(minutes) else { return false }

        let stage = stage(containing: minutes)
        return (minutes - stage.start) % stage.step == 0
    }

    /// The next selectable value above `minutes`, strictly above it.
    ///
    /// Saturating rather than optional: at the top of the scale it answers the
    /// top. A stepper asks this to fill a value, not to find out whether it may
    /// — that question is `minutes < range.upperBound`, and an optional here
    /// would push a `??` into every call site to say the same thing.
    func next(after minutes: Int) -> Int {
        let value = clamped(minutes)
        guard value < range.upperBound else { return range.upperBound }

        let stage = stage(containing: value)
        let stepped = stage.start + ((value - stage.start) / stage.step + 1) * stage.step

        // A stage boundary is a detent of the stage below it, so a step can
        // never jump over one — unless a future stage is added off that grid,
        // which is exactly when landing short is the harmless answer.
        let capped = nextStageStart(above: value).map { min(stepped, $0) } ?? stepped
        return min(capped, range.upperBound)
    }

    /// The next selectable value below `minutes`, strictly below it. Saturating
    /// at the bottom, for the same reason as `next(after:)`.
    func previous(before minutes: Int) -> Int {
        let value = clamped(minutes)
        guard value > range.lowerBound else { return range.lowerBound }

        // Asking from one below turns "the largest detent under this value"
        // into a plain floor, and answers a value that sits exactly on a stage
        // boundary with the finer stage underneath rather than with itself.
        let target = value - 1
        let stage = stage(containing: target)
        let stepped = stage.start + ((target - stage.start) / stage.step) * stage.step
        return max(stepped, range.lowerBound)
    }

    /// The selectable value closest to an arbitrary one — what a scrolling
    /// picker needs when it comes to rest between two detents.
    func nearest(to minutes: Int) -> Int {
        nearest(to: Double(minutes))
    }

    /// The same question from a scroll offset, which is a fraction of a minute
    /// far more often than it is a whole one.
    ///
    /// A tie goes downwards, so a picker released exactly halfway settles on
    /// the value it has already travelled past rather than on the one it has
    /// not reached. Deterministic either way; what matters is that it is not
    /// left to the rounding mode of whoever calls.
    ///
    /// A non-finite offset is a bug upstream, and the bottom of the scale is
    /// the one answer that cannot make it worse.
    func nearest(to minutes: Double) -> Int {
        guard minutes.isFinite else { return range.lowerBound }

        let value = min(max(minutes, Double(range.lowerBound)), Double(range.upperBound))
        let floored = Int(value.rounded(.down))
        let below = isSelectable(floored) ? floored : previous(before: floored)
        let above = next(after: below)

        return (value - Double(below)) <= (Double(above) - value) ? below : above
    }

    /// Range only, no snapping. For the values that are counted rather than
    /// dialled — and as the first half of every `nearest(to:)`.
    func clamped(_ minutes: Int) -> Int {
        min(max(minutes, range.lowerBound), range.upperBound)
    }

    // MARK: - Stages

    /// The stage a value falls in: the last one that has begun by then.
    private func stage(containing minutes: Int) -> Stage {
        stages.last { $0.start <= minutes } ?? stages[0]
    }

    private func nextStageStart(above minutes: Int) -> Int? {
        stages.first { $0.start > minutes }?.start
    }
}
