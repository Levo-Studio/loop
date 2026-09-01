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

    /// The ends of the scale. Both ends are selectable values, and the `init`
    /// insists on it — an upper bound that is not on a detent could never be
    /// reached, and the end of a scale is the one value a user is most likely
    /// to drag for.
    let range: ClosedRange<Int>

    /// Ordered by `start`, coarsest last.
    let stages: [Stage]

    /// The preconditions guard constants, not stored data: scales are built
    /// from literals in `LoopTimerLimits`, never decoded. An empty stage list
    /// or a zero step would divide by zero on the first question asked, so
    /// failing here fails on the first launch of a wrong build rather than in
    /// someone's hands.
    ///
    /// The ends are checked for the opposite reason: a bound that is off the
    /// detents fails *silently*. `next(after:)` and `nearest(to:)` both
    /// saturate at the bound, so they would keep answering a value that
    /// `isSelectable` calls false, and a picker would rest somewhere it says
    /// it cannot. Since adding a stage is meant to be a one-line change, the
    /// line that makes a bound unreachable has to say so.
    init(range: ClosedRange<Int>, stages: [Stage]) {
        precondition(!stages.isEmpty, "A minute scale needs at least one stage.")
        precondition(stages.allSatisfy { $0.step > 0 }, "A stage without a positive step has no detents.")

        self.range = range
        self.stages = stages.sorted { $0.start < $1.start }

        precondition(isSelectable(range.lowerBound), "The bottom of a scale has to be a selectable value.")
        precondition(isSelectable(range.upperBound), "The top of a scale has to be a selectable value.")

        // `detentOffset(of:)` counts from the first stage's start, so a range
        // reaching below it would have nothing to count from and would answer
        // a position that runs backwards. Every scale in the app starts both
        // at zero; this is the line that says the two are not independent.
        precondition(
            self.stages[0].start <= range.lowerBound,
            "A scale's first stage has to begin at or below the bottom of its range."
        )
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

    /// How far apart the detents are at a value — the step of the stage it
    /// falls in.
    ///
    /// For a drawing that has to say something about the step without knowing
    /// where the boundaries are. Everything else here answers in minutes; this
    /// is the one question whose answer is the grid itself.
    func step(at minutes: Int) -> Int {
        stage(containing: clamped(minutes)).step
    }

    // MARK: - Position

    /// Where a value sits when the scale is measured in **detents** rather than
    /// in minutes — the number of selectable values between the bottom of the
    /// scale and this one.
    ///
    /// This is the coordinate a scrolling scale is drawn in. Drawn in minutes,
    /// four fifths of the distance a finger travels above two hours passes over
    /// positions that cannot be chosen, and thirty hours costs about thirty
    /// full-width swipes. In detents every point of travel buys a value, and
    /// the same thirty hours costs about eight.
    ///
    /// Fractional, and monotonic in `minutes`, because a finger is between
    /// detents for all but an instant of a drag. Inside the one-minute stage a
    /// detent *is* a minute, so the two coordinates are the same number there
    /// and nothing about the fine part of a scale changes.
    ///
    /// Counted from the first stage's start rather than from `range.lowerBound`
    /// so that two scales sharing a stage list agree on where a value sits.
    func detentOffset(of minutes: Double) -> Double {
        guard minutes.isFinite else { return 0 }

        let value = min(max(minutes, Double(range.lowerBound)), Double(range.upperBound))

        var offset: Double = 0
        for (index, stage) in stages.enumerated() {
            let start = Double(stage.start)
            guard value > start else { break }

            let end = index + 1 < stages.count ? Double(stages[index + 1].start) : .infinity
            offset += (min(value, end) - start) / Double(stage.step)
        }
        return offset
    }

    /// The value at a position on that same detent coordinate — the inverse of
    /// `detentOffset(of:)`, which is what turns a scroll position back into a
    /// duration.
    ///
    /// Clamped to the range, so a finger that has run past an end answers the
    /// end rather than a value the scale does not have.
    func minutes(atDetentOffset offset: Double) -> Double {
        guard offset.isFinite else { return Double(range.lowerBound) }

        var remaining = offset
        var value = Double(stages[0].start)

        for (index, stage) in stages.enumerated() {
            let start = Double(stage.start)
            let step = Double(stage.step)

            guard index + 1 < stages.count else {
                value = start + remaining * step
                break
            }

            // How many detents this stage holds before the next one takes over.
            let span = (Double(stages[index + 1].start) - start) / step
            if remaining <= span {
                value = start + remaining * step
                break
            }
            remaining -= span
        }

        return min(max(value, Double(range.lowerBound)), Double(range.upperBound))
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
