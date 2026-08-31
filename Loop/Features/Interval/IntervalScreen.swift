import SwiftUI

// MARK: - Interval

/// Focus and break blocks over a number of rounds, sharing the one rising area.
/// Only the status pill and the round counter say which block is running.
///
/// The screen owns an `IntervalTimer` and draws whatever it reports for the
/// instant in `now`. It decides nothing about the schedule: which block is
/// running, how much of it is left, how tall the area stands and whether Skip
/// is legal all arrive together in one `Snapshot`.
struct IntervalScreen: View {

    /// The run itself. Held here rather than inside a slot of the scaffold —
    /// those closures are built twice, and two copies of a timer would drift
    /// apart on the first tick.
    @State private var timer = IntervalTimer()

    /// The instant the page is drawn at. Every displayed value is derived from
    /// it, so the screen never counts anything; it re-reads the clock.
    @State private var now = Date.now

    @Environment(\.loopMetrics) private var metrics

    var body: some View {
        // One snapshot per frame, taken from a single instant and a single
        // walk of the schedule. Asking the timer for the phase, then the
        // block, then the fraction would be three different `now` values, and
        // two of those either side of a block boundary put a "Focus" pill over
        // an area that belongs to the break.
        let snapshot = timer.snapshot(at: now)

        PageScaffold(fillFraction: snapshot.fraction) {
            pill(snapshot)
        } content: {
            content(snapshot)
        } controls: {
            controls(snapshot)
        }
        // Outside the slots on purpose: a `.task` inside one would be installed
        // on both layers of the fill surface and tick twice.
        .task(id: snapshot.phase) {
            await follow(snapshot.phase)
        }
    }

    // MARK: - Ticking

    /// Republishes `now` on a fixed cadence while a block is running.
    ///
    /// The cadence is `LoopMotion.tickInterval` because the fill animation is
    /// exactly that long: each step of the area starts as the previous one
    /// lands, so it reads as a continuous rise rather than as a jump once a
    /// second. A faster tick would be re-targeting an animation that has not
    /// finished, a slower one would leave the area standing still between
    /// steps.
    ///
    /// The deadline is absolute rather than a sleep of a fixed length. A late
    /// frame then costs one tick instead of pushing every following tick out
    /// by the same amount, which is what makes the seconds digit change on the
    /// second over a long run. The value shown still comes from `Date.now`, so
    /// even a badly missed tick displays the right time rather than a count.
    private func follow(_ phase: IntervalTimer.Phase) async {
        guard phase == .running else { return }

        var deadline = ContinuousClock.now
        while !Task.isCancelled {
            deadline = deadline.advanced(by: .seconds(LoopMotion.tickInterval))
            try? await Task.sleep(until: deadline, clock: .continuous)
            now = .now
        }
    }

    // MARK: - Status pill

    @ViewBuilder private func pill(_ snapshot: IntervalTimer.Snapshot) -> some View {
        switch snapshot.phase {
        case .setup:
            StatusPill(label: LoopStrings.interval)

        case .running:
            StatusPill(
                label: Self.blockLabel(snapshot.blockKind),
                detail: LoopStrings.roundCounter(current: snapshot.round, total: snapshot.rounds)
            )

        case .paused:
            // "Paused" takes the pill's own label, so the block moves into the
            // detail beside the counter.
            StatusPill(
                label: LoopStrings.pausedStatus,
                detail: LoopStrings.blockAndRound(
                    Self.blockLabel(snapshot.blockKind),
                    current: snapshot.round,
                    total: snapshot.rounds
                )
            )

        case .finished:
            // One run of text and no accent dot: there is no state left to
            // indicate once the schedule is over.
            StatusPill(label: LoopStrings.doneRounds(snapshot.rounds), emphasis: .solid)
        }
    }

    private static func blockLabel(_ kind: IntervalTimer.BlockKind) -> LocalizedStringResource {
        switch kind {
        case .focus: LoopStrings.focus
        case .break: LoopStrings.breakBlock
        }
    }

    // MARK: - Content

    @ViewBuilder private func content(_ snapshot: IntervalTimer.Snapshot) -> some View {
        switch snapshot.phase {
        case .setup:
            setup

        case .running:
            TimeDisplay(
                time: LoopTimeFormat.remaining(snapshot.remaining),
                secondary: LoopStrings.ofDuration(LoopTimeFormat.clock(seconds: Int(snapshot.blockDuration)))
            )

        case .paused:
            TimeDisplay(time: LoopTimeFormat.remaining(snapshot.remaining), secondary: LoopStrings.paused)

        case .finished:
            // The two totals on this page are different numbers and both are
            // right. Setup sums the whole run, breaks included; this line sums
            // the focus blocks only, which is what "focused" means.
            TimeDisplay(
                time: LoopTimeFormat.hoursAndMinutes(timer.focusedDuration),
                secondary: LoopStrings.hoursFocused(timer.focusedDuration)
            )
        }
    }

    /// The two scales, the round stepper and the sum of the run.
    ///
    /// No rising area behind it: the area measures a block, and in setup no
    /// block is running. It is also centred without the time block's −30 pt
    /// offset — the export draws this state as a column of controls rather
    /// than as a time to be read against the page.
    private var setup: some View {
        VStack(spacing: metrics.intervalSetupSpacing) {
            ScaleSlider(
                label: LoopStrings.focus,
                minutes: focusMinutes,
                maximumMinutes: LoopTimerLimits.durationMinutes.upperBound,
                numberEvery: Self.focusNumberInterval,
                unit: LoopStrings.minutesUnit
            )

            ScaleSlider(
                label: LoopStrings.breakBlock,
                minutes: breakMinutes,
                maximumMinutes: LoopTimerLimits.breakMinutes.upperBound,
                numberEvery: Self.breakNumberInterval,
                unit: LoopStrings.minutesUnit
            )

            SetupDivider()

            LoopStepper(
                label: LoopStrings.rounds,
                value: rounds,
                range: LoopTimerLimits.rounds,
                unit: LoopStrings.timesUnit
            )

            TotalLine(duration: timer.plannedDuration)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Controls

    @ViewBuilder private func controls(_ snapshot: IntervalTimer.Snapshot) -> some View {
        switch snapshot.phase {
        case .setup:
            ControlRow(
                // A run needs something to focus on: with the focus scale at
                // zero the engine refuses to start, so the button says so
                // rather than being tapped for nothing.
                primary: .init(LoopStrings.start, isEnabled: timer.canStart) { act { $0.start(at: $1) } },
                // Nothing has run yet, so there is nothing to return to. The
                // export draws it dimmed and in place.
                secondary: .init(LoopStrings.reset, isEnabled: false) {}
            )

        case .running:
            ControlRow(
                primary: .init(LoopStrings.pause) { act { $0.pause(at: $1) } },
                // Taken from the snapshot rather than from the block kind. The
                // rule that a focus block cannot be shortened belongs to the
                // engine; a second copy of it here is a second place to get it
                // wrong. The button stays in the row at 45 % either way, so
                // the layout does not move at a block change.
                secondary: .init(LoopStrings.skip, isEnabled: snapshot.canSkip) { act { $0.skip(at: $1) } }
            )

        case .paused:
            ControlRow(
                primary: .init(LoopStrings.resume) { act { $0.resume(at: $1) } },
                secondary: .init(LoopStrings.stop) { reset() }
            )

        case .finished:
            ControlRow(
                primary: .init(LoopStrings.restart) { act { $0.start(at: $1) } },
                secondary: .init(LoopStrings.close) { reset() }
            )
        }
    }

    // MARK: - Acting on the timer

    /// Runs a change against a freshly read instant and redraws at the same
    /// one.
    ///
    /// `now` is up to a tick old when a button is tapped, and handing that
    /// stale instant to the engine would start a run in the past. Reading the
    /// clock once and using the same value for the change and for the next
    /// frame keeps the two in step.
    private func act(_ change: (inout IntervalTimer, Date) -> Void) {
        let instant = Date.now
        change(&timer, instant)
        now = instant
    }

    /// Back to setup with the scales untouched — what Stop and Close both do.
    private func reset() {
        timer.reset()
        now = .now
    }

    // MARK: - Setup bindings

    /// The scales and the stepper write through the engine rather than into
    /// state of their own, so the clamps apply once and in one place.
    private var focusMinutes: Binding<Int> {
        Binding(get: { timer.focusMinutes }, set: { value in act { $0.setFocusMinutes(value, at: $1) } })
    }

    private var breakMinutes: Binding<Int> {
        Binding(get: { timer.breakMinutes }, set: { value in act { $0.setBreakMinutes(value, at: $1) } })
    }

    private var rounds: Binding<Int> {
        Binding(get: { timer.rounds }, set: { value in act { $0.setRounds(value, at: $1) } })
    }

    // MARK: - Scale numbers

    // How often each scale prints a number. Both are the export's values — a
    // number every 15 minutes on the hour-long focus scale, every 10 on the
    // half-hour break scale — and they belong in `LoopMetrics` beside the tick
    // interval rather than here. They sit in the feature only until the design
    // layer has somewhere to put them.
    private static let focusNumberInterval = 15
    private static let breakNumberInterval = 10
}

// MARK: - Divider

/// The hairline between the two scales and the round stepper.
///
/// Its own view rather than a rectangle inline, because `\.loopInk` is injected
/// by `FillSurface` from *inside* the scaffold: read on the screen it would be
/// the environment's default, and the line would keep the background tone where
/// it crosses the fill.
private struct SetupDivider: View {

    @Environment(\.loopInk) private var ink
    @Environment(\.loopMetrics) private var metrics

    var body: some View {
        Rectangle()
            .fill(ink.hair)
            .frame(height: metrics.hairlineWidth)
    }
}

// MARK: - Total

/// "Total 1:55 h" under the stepper: the whole run, breaks included.
///
/// Not `rounds × (focus + break)` — the last round has no break after it, so a
/// 25/5/4 run is 1:55 and not 2:00. The number comes from the engine, which is
/// the one place the schedule is laid out.
private struct TotalLine: View {

    let duration: TimeInterval

    @Environment(\.loopInk) private var ink
    @Environment(\.loopTypography) private var typography

    var body: some View {
        Text(LoopStrings.total(LoopTimeFormat.hoursAndMinutes(duration)))
            .loopTextStyle(typography.fieldLabel)
            .foregroundStyle(ink.base)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    IntervalScreen()
}
