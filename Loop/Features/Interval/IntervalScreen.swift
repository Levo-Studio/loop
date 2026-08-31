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

    /// The run itself, owned by the app rather than by this page. Read above
    /// the scaffold — those closures are built twice and would each read their
    /// own copy — and held outside the view because a schedule has to survive
    /// the process: an interval left running is exactly the run nobody is
    /// watching the screen for.
    @Environment(LoopTimers.self) private var timers

    /// The instant the page is drawn at. Every displayed value is derived from
    /// it, so the screen never counts anything; it re-reads the clock.
    @State private var now = Date.now

    @Environment(\.loopMetrics) private var metrics

    /// Read on the screen rather than inside a slot: the sound switch decides
    /// whether a boundary is audible, and the place that notices the boundary
    /// is this one. A slot is built twice for the two-tone layers, and an
    /// observation installed there would fire — and play — twice.
    @Environment(LoopSettings.self) private var settings

    var body: some View {
        // One snapshot per frame, taken from a single instant and a single
        // walk of the schedule. Asking the timer for the phase, then the
        // block, then the fraction would be three different `now` values, and
        // two of those either side of a block boundary put a "Focus" pill over
        // an area that belongs to the break.
        let snapshot = timers.interval.snapshot(at: now)

        PageScaffold(fill: fill(snapshot)) {
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
        // Outside the slots for the same reason as the tick, and for a louder
        // one: a boundary noticed on both layers of the fill surface is a tone
        // played twice.
        .onChange(of: Boundary(snapshot)) { previous, current in
            announce(from: previous, to: current)
        }
        // Once per tick with the frame's own snapshot, so the lock screen is
        // fed the same values the page is drawn from. The controller decides
        // when that is worth an update — a block, a round, the accent, a pause
        // or a moved end — and does nothing on the ticks in between, which is
        // why this can sit on the draw path rather than in a second observer
        // that would have to work out the same transitions again.
        .onChange(of: ActivityInput(now: now, accent: settings.accent), initial: true) {
            LoopActivityController.shared.update(interval: snapshot, accent: settings.accent, at: now)
        }
    }

    // MARK: - The rising area

    /// How full the area is, and which block it is measuring.
    ///
    /// Setup has no area at all: the area measures a block, and in setup no
    /// block is running. Everything else hands over the fraction together with
    /// the identity below, so `FillSurface` can tell a block ending from a
    /// block progressing and drop the area rather than sliding it down.
    private func fill(_ snapshot: IntervalTimer.Snapshot) -> FillProgress {
        guard snapshot.phase != .setup else { return .none }

        return FillProgress(
            fraction: snapshot.fraction,
            block: FillBlock(
                kind: snapshot.blockKind,
                round: snapshot.round,
                isFinished: snapshot.phase == .finished
            )
        )
    }

    /// What the area is measuring.
    ///
    /// The kind and the round together, because focus 2 and break 2 are
    /// different blocks. Deliberately nothing that moves while a block runs —
    /// putting the fraction or the remaining time in here would make every
    /// tick a new block and turn the whole rise into a stutter of jumps.
    ///
    /// Running and paused share an identity on purpose: holding a timer
    /// freezes the area where it stands, and a change of identity would drop
    /// it to nothing instead.
    ///
    /// `isFinished` looks redundant next to those two and is not. A one-round
    /// run restarts from the finished screen straight back into round 1 of the
    /// same kind, so without it the identity would be unchanged across a
    /// restart and the area would slide from full back to empty — the exact
    /// slide this type exists to prevent. It costs nothing anywhere else: the
    /// last focus block and the finished screen are both at 1.0, so the
    /// identity changing between them is a jump from full to full.
    private struct FillBlock: Hashable {
        let kind: IntervalTimer.BlockKind
        let round: Int
        let isFinished: Bool
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

    // MARK: - Live Activity

    /// What the lock screen has to be told about.
    ///
    /// The instant carries every move of the run — a tick, a pause, a resume, a
    /// skip — because all four write `now`. The accent does not, and a colour
    /// changed on the settings page while a run is paused would otherwise sit
    /// on the lock screen until the next tick, which may never come.
    private struct ActivityInput: Equatable {
        let now: Date
        let accent: LoopAccent
    }

    // MARK: - Sound

    /// Where the run stands, reduced to the three things a boundary changes.
    ///
    /// Not the snapshot itself: the snapshot carries the remaining time, so it
    /// differs on every tick and would announce a boundary a second. Kind and
    /// round together identify the block — focus 2 and break 2 are different
    /// blocks — and the phase carries the end of the run, which is a change of
    /// phase with no block after it.
    private struct Boundary: Equatable {
        let phase: IntervalTimer.Phase
        let kind: IntervalTimer.BlockKind
        let round: Int

        init(_ snapshot: IntervalTimer.Snapshot) {
            phase = snapshot.phase
            kind = snapshot.blockKind
            round = snapshot.round
        }
    }

    /// Plays the tone that belongs to a change of block, if there is one.
    ///
    /// **One tone per boundary, not both halves of the pair.** A boundary is a
    /// single instant — one block ends exactly as the next begins — so playing
    /// the ending and the beginning there gives the ear one smear rather than
    /// two messages. Which of the two is played is what carries the meaning:
    ///
    /// - into a break, the rising two-note figure, "the work is over";
    /// - into a focus block, the single note, "back to it".
    ///
    /// That is the only reading in which two tones buy anything with the phone
    /// face down, which is the situation the whole feature is for.
    ///
    /// Starting a run and resuming from a pause are deliberately silent: the
    /// finger that did it was on the screen, and a tone for something the user
    /// just tapped is noise. Skip is not — it lands on the next focus block and
    /// is announced like any other arrival there, so a run that is being
    /// skipped through sounds the same as one that is being waited out.
    private func announce(from previous: Boundary, to current: Boundary) {
        if current.phase == .finished, previous.phase == .running {
            LoopSounds.play(.timerFinished, enabled: settings.sound)
            return
        }

        guard current.phase == .running, previous.phase == .running else { return }
        guard current.kind != previous.kind || current.round != previous.round else { return }

        LoopSounds.play(current.kind == .break ? .blockEnded : .blockBegan, enabled: settings.sound)
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
            setup(snapshot)

        case .running:
            timeBlock(
                snapshot,
                time: LoopTimeFormat.remaining(snapshot.remaining),
                secondary: LoopStrings.ofDuration(LoopTimeFormat.clock(seconds: Int(snapshot.blockDuration)))
            )

        case .paused:
            // "on hold" rather than "paused": the pill above already says
            // "Paused", and the export draws two different words here for
            // exactly that reason.
            timeBlock(
                snapshot,
                time: LoopTimeFormat.remaining(snapshot.remaining),
                secondary: LoopStrings.onHold
            )

        case .finished:
            // The two totals on this page are different numbers and both are
            // right. Setup sums the whole run, breaks included; this line sums
            // the focus blocks only, which is what "focused" means.
            TimeDisplay(
                time: LoopTimeFormat.hoursAndMinutes(timers.interval.focusedDuration),
                secondary: LoopStrings.hoursFocused(timers.interval.focusedDuration)
            )
        }
    }

    /// The time, with the `BREAK` headline over it on a break and nothing over
    /// it on a focus block.
    ///
    /// **The asymmetry is deliberate, not an omission.** The pill already names
    /// the block, so a headline on both would say the same thing twice and stop
    /// distinguishing anything; the headline earns its 32 pt precisely because
    /// it appears on one of the two states. Break is the one that has to be
    /// unmistakable from across a desk — a focus block missed for a glance
    /// costs nothing, a break missed costs the break.
    ///
    /// A paused break keeps it. The pill above says "Paused" and the block is
    /// still a break; taking the headline away on hold would make the one state
    /// where someone looks up to check hardest to read.
    @ViewBuilder private func timeBlock(
        _ snapshot: IntervalTimer.Snapshot,
        time: String,
        secondary: LocalizedStringResource
    ) -> some View {
        if snapshot.blockKind == .break {
            BreakTimeBlock(time: time, secondary: secondary)
        } else {
            TimeDisplay(time: time, secondary: secondary)
        }
    }

    /// The two scales, the round stepper and the sum of the run.
    ///
    /// No rising area behind it: the area measures a block, and in setup no
    /// block is running. It is also centred without the time block's −30 pt
    /// offset — the export draws this state as a column of controls rather
    /// than as a time to be read against the page.
    ///
    /// The three scales are drawn from the snapshot and written through the
    /// timer's setters, so there is one read path and one clamping site. The
    /// sum underneath is the documented exception: it is arithmetic over the
    /// three scales rather than anything the run moves.
    private func setup(_ snapshot: IntervalTimer.Snapshot) -> some View {
        VStack(spacing: metrics.intervalSetupSpacing) {
            ScaleSlider(
                label: LoopStrings.focus,
                minutes: focusMinutes(snapshot.focusMinutes),
                minuteScale: LoopTimerLimits.focus,
                numberEvery: LoopMetrics.focusNumberInterval,
                unit: LoopStrings.minutesUnit
            )

            ScaleSlider(
                label: LoopStrings.breakBlock,
                minutes: breakMinutes(snapshot.breakMinutes),
                minuteScale: LoopTimerLimits.breakLength,
                numberEvery: LoopMetrics.breakNumberInterval,
                unit: LoopStrings.minutesUnit
            )

            SetupDivider()

            LoopStepper(
                label: LoopStrings.rounds,
                value: rounds(snapshot.rounds),
                range: LoopTimerLimits.rounds,
                unit: LoopStrings.timesUnit
            )

            TotalLine(duration: timers.interval.plannedDuration)
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
                primary: .init(LoopStrings.start, isEnabled: snapshot.canStart) { act { $0.start(at: $1) } },
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
                // Close is a tap, and the rule is asked rather than assumed.
                // `LoopDismissal` answers `false` for the interval whatever the
                // setting says — the countdown is the alarm, this is not — and
                // one function answering for both screens is why the two cannot
                // quietly drift apart.
                //
                // So this is a constant `true` today, and it has to stay one
                // until there is something to swipe: this screen draws no
                // dismissal gesture, so an answer of `true` would dim the only
                // way off the finished state and strand the run there. Whoever
                // gives the interval a swipe wires the gesture first and this
                // flag second, not the other way round.
                secondary: .init(LoopStrings.close, isEnabled: !requiresSwipe) { reset() }
            )
        }
    }

    /// Whether the finished state waits for a gesture before it lets go.
    ///
    /// Always `false` here: the interval never requires a swipe, not at a block
    /// boundary and not at the end. A boundary plays its tone and the run
    /// carries on by itself, because a timer that stops a session to be wiped
    /// at has interrupted the thing it exists to protect.
    private var requiresSwipe: Bool {
        LoopDismissal.requiresSwipe(.interval, swipeToDismissEnabled: settings.swipeToDismiss)
    }

    // MARK: - Acting on the timer

    /// Runs a change against a freshly read instant and redraws at the same
    /// one.
    ///
    /// `now` is up to a tick old when a button is tapped, and handing that
    /// stale instant to the engine would start a run in the past. Reading the
    /// clock once and using the same value for the change and for the next
    /// frame keeps the two in step.
    /// The change goes through the owner rather than into a local copy: that
    /// is what puts the new state on disk, and it is the only write path there
    /// is.
    private func act(_ change: (inout IntervalTimer, Date) -> Void) {
        let instant = Date.now
        timers.update(\.interval) { change(&$0, instant) }
        now = instant
    }

    /// Back to setup with the scales untouched — what Stop and Close both do.
    private func reset() {
        act { interval, _ in interval.reset() }
    }

    // MARK: - Setup bindings

    /// Reading is drawing, so it comes off the snapshot the frame was built
    /// from; writing is a clamped mutation, so it goes through the engine's
    /// setters. Splitting the two directions keeps one read path and one place
    /// where a value out of range is dealt with.
    private func focusMinutes(_ current: Int) -> Binding<Int> {
        Binding(get: { current }, set: { value in act { $0.setFocusMinutes(value, at: $1) } })
    }

    private func breakMinutes(_ current: Int) -> Binding<Int> {
        Binding(get: { current }, set: { value in act { $0.setBreakMinutes(value, at: $1) } })
    }

    private func rounds(_ current: Int) -> Binding<Int> {
        Binding(get: { current }, set: { value in act { $0.setRounds(value, at: $1) } })
    }
}

// MARK: - Break time block

/// The `BREAK` headline and the time under it, as one centred block.
///
/// Its own view rather than a `VStack` in the screen, because `\.loopInk` is
/// injected by `FillSurface` from *inside* the scaffold: read on the screen it
/// would be the environment's default, and the headline would keep the
/// background tone where it crosses the fill.
///
/// Full-opacity ink, unlike every other uppercase label on the page. The pill,
/// the secondary line and the field labels are all dimmed to 62 % because they
/// annotate something; this one is the statement.
private struct BreakTimeBlock: View {

    let time: String
    let secondary: LocalizedStringResource

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopInk) private var ink

    var body: some View {
        VStack(spacing: metrics.breakHeadlineSpacing) {
            Text(LoopStrings.breakBlock)
                .loopTextStyle(typography.breakHeadline)
                .foregroundStyle(ink.base)

            TimeDisplay(time: time, secondary: secondary)
                // Held to its own height and put back where it started, so the
                // gap above the time is the metric rather than whatever slack
                // was left over: a `TimeDisplay` left to fill the page centres
                // itself in what remains under the headline, and its own −30 pt
                // offset would then close that gap on top of that. The offset
                // belongs to the block as a whole, so it is taken off here and
                // applied once below.
                .fixedSize(horizontal: false, vertical: true)
                .offset(y: -metrics.timeBlockOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: metrics.timeBlockOffset)
    }
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
        .environment(LoopSettings(defaults: UserDefaults(suiteName: "preview") ?? .standard))
        .environment(LoopTimers(store: TimerStateStore(defaults: UserDefaults(suiteName: "preview") ?? .standard)))
}
