import SwiftUI

// MARK: - Countdown

/// One duration, counted down, with the rising area showing how much of it has
/// gone.
///
/// The page has exactly one control: the duration. Rounds, a focus block and a
/// break belong to the interval page — a countdown that offered them would be an
/// interval with a piece missing.
///
/// Everything drawn here is a pure function of one snapshot. `PageScaffold`
/// builds its three slots twice to cut the two-tone edge, so the state lives up
/// here and the slots only read it: no `@State`, no `.task` and no
/// `.sensoryFeedback` inside a closure below.
struct CountdownScreen: View {

    /// The sound switch and the swipe-to-dismiss switch. Read here, above the
    /// scaffold, because everything below it is built twice — and because both
    /// answers are needed by code that is not a view at all.
    @Environment(LoopSettings.self) private var settings

    /// The timer itself. A value, not an observable object — the engine holds no
    /// view and publishes nothing; a new frame comes from `now` moving.
    @State private var timer = CountdownTimer()

    /// The instant the current frame is drawn at. Every displayed value is
    /// derived from it, so the phase, the time and the area can never disagree
    /// about what time it is.
    @State private var now = Date.now

    /// Identifies the run the rising area is measuring, so a restart reads as a
    /// new block and jumps rather than sliding down from full.
    ///
    /// Counted here because nothing on the snapshot identifies a run. The
    /// tracker's `startedAt` is the obvious candidate and is the wrong one: it
    /// is rewritten on every resume, so a held run would come back as a new
    /// block. This changes on `start` alone and holds still across a pause.
    @State private var run = 0

    var body: some View {
        // One snapshot per frame. Asking the timer for the phase, then the
        // time, then the fraction would be three different instants, and one
        // landing either side of the finish shows a full area under a running
        // pill.
        let snapshot = timer.snapshot(at: now)

        // Asked of `LoopDismissal` rather than read straight off the setting.
        // The interval draws a finished state too and ignores the same switch;
        // that asymmetry is one function's job, and a screen that re-derived it
        // would be the copy that keeps the old answer the day the rule changes.
        let requiresSwipe = snapshot.phase == .finished
            && LoopDismissal.requiresSwipe(.countdown, swipeToDismissEnabled: settings.swipeToDismiss)

        PageScaffold(fill: fill(for: snapshot)) {
            pill(for: snapshot)
        } content: {
            content(for: snapshot)
        } controls: {
            controls(for: snapshot, requiresSwipe: requiresSwipe)
        }
        // The tick sits on the screen rather than in a slot, because a slot is
        // built twice and would run two of them.
        .task(id: snapshot.phase) { await run(phase: snapshot.phase) }
        // Same reason, and one more: the shell pages horizontally through a
        // scroll view, so the dismissal has to run alongside that gesture
        // rather than in place of it. `.all` only while a swipe is actually
        // required, so every other state is untouched.
        .simultaneousGesture(dismissSwipe, including: requiresSwipe ? .all : .subviews)
    }

    // MARK: - Dismissing

    /// The swipe that clears a finished countdown when the setting asks for
    /// one.
    ///
    /// **Vertical**, and deliberately not the horizontal slide a lock-screen
    /// alarm uses: horizontal belongs to the shell, which moves between the
    /// five pages with it. Read horizontally here, the countdown would dismiss
    /// itself on the way to the settings page.
    ///
    /// The axis is the whole test. `DragGesture` already refuses anything
    /// shorter than its minimum distance, so what is left to decide is only
    /// whether the movement was a dismissal or a page turn, and that is which
    /// way it went — not how far, which would be a length this screen has no
    /// drawn value for.
    private var dismissSwipe: some Gesture {
        DragGesture()
            .onEnded { gesture in
                guard abs(gesture.translation.height) > abs(gesture.translation.width) else { return }
                stop()
            }
    }

    // MARK: - Status

    @ViewBuilder private func pill(for snapshot: CountdownTimer.Snapshot) -> some View {
        switch snapshot.phase {
        case .idle, .running:
            StatusPill(label: LoopStrings.countdown)
        case .paused:
            // "Countdown · paused": the page keeps its name and the state is a
            // dimmed qualifier after it.
            StatusPill(label: LoopStrings.countdown, detail: LoopStrings.pausedDetail)
        case .finished:
            // No dot and the stronger tone — there is no longer a state to
            // indicate.
            StatusPill(label: LoopStrings.done, emphasis: .solid)
        }
    }

    // MARK: - Content

    @ViewBuilder private func content(for snapshot: CountdownTimer.Snapshot) -> some View {
        switch snapshot.phase {
        case .idle:
            CountdownSetup(time: LoopTimeFormat.remaining(snapshot.duration), minutes: durationMinutes(for: snapshot))
        case .running:
            TimeDisplay(
                time: LoopTimeFormat.remaining(snapshot.remaining),
                secondary: LoopStrings.ofDuration(LoopTimeFormat.remaining(snapshot.duration))
            )
        case .paused:
            TimeDisplay(time: LoopTimeFormat.remaining(snapshot.remaining), secondary: LoopStrings.onHold)
        case .finished:
            TimeDisplay(
                time: LoopTimeFormat.remaining(snapshot.remaining),
                secondary: LoopStrings.completed(LoopTimeFormat.remaining(snapshot.duration))
            )
        }
    }

    /// The scale's value. A binding rather than a copy: `ScaleSlider` is built
    /// twice inside the fill surface, and two copies of the same number would
    /// drift apart the moment one of them was dragged.
    ///
    /// The two directions are not the same operation. Reading is drawing — the
    /// "25 min" beside the scale, every frame — so it comes off the snapshot
    /// like everything else on the page. Writing is a clamped mutation, so it
    /// goes through the engine's setter and the clamp stays in the one place
    /// that owns it.
    private func durationMinutes(for snapshot: CountdownTimer.Snapshot) -> Binding<Int> {
        Binding(
            get: { snapshot.durationMinutes },
            set: { minutes in
                let instant = Date.now
                timer.setDuration(minutes: minutes, at: instant)
                now = instant
            }
        )
    }

    // MARK: - Controls

    @ViewBuilder private func controls(
        for snapshot: CountdownTimer.Snapshot,
        requiresSwipe: Bool
    ) -> some View {
        switch snapshot.phase {
        case .idle:
            ControlRow(
                primary: .init(LoopStrings.start, isEnabled: snapshot.canStart) { start() },
                // Dead but present, exactly as the export draws it: there is
                // nothing to reset before a run, and hiding the button would
                // move the row the moment one started.
                secondary: .init(LoopStrings.reset, isEnabled: false) {}
            )
        case .running:
            ControlRow(
                primary: .init(LoopStrings.pause) { pause() },
                secondary: .init(LoopStrings.stop) { stop() }
            )
        case .paused:
            ControlRow(
                primary: .init(LoopStrings.resume) { resume() },
                secondary: .init(LoopStrings.stop) { stop() }
            )
        case .finished:
            ControlRow(
                primary: .init(LoopStrings.restart) { start() },
                // Dead but present while a swipe is required, exactly as the
                // idle row draws its reset: a finished countdown that can be
                // tapped away is not the alarm the setting asks for, and
                // hiding the button would move the row in the one state where
                // it has to hold still. Restart stays live throughout — it
                // begins a new run rather than dismissing this one.
                secondary: .init(LoopStrings.close, isEnabled: !requiresSwipe) { stop() }
            )
        }
    }

    // MARK: - Acting

    /// Each of these settles the frame on the same instant it hands to the
    /// engine, so the tap redraws at the time it happened rather than at the
    /// time of the last tick.
    private func start() {
        let instant = Date.now
        timer.start(at: instant)
        now = instant
        run += 1
    }

    /// The area and the block it measures. Idle has no block at all; a finished
    /// run keeps the identity it counted under, so the area stays full instead
    /// of restarting in place.
    private func fill(for snapshot: CountdownTimer.Snapshot) -> FillProgress {
        switch snapshot.phase {
        case .idle: .none
        case .running, .paused, .finished: FillProgress(fraction: snapshot.fraction, block: run)
        }
    }

    private func pause() {
        let instant = Date.now
        timer.pause(at: instant)
        now = instant
    }

    private func resume() {
        let instant = Date.now
        timer.resume(at: instant)
        now = instant
    }

    private func stop() {
        timer.reset()
        now = .now
    }

    // MARK: - Ticking

    /// Moves `now` forward while the countdown runs.
    ///
    /// One tick a second, and no faster. The area is animated by `LoopMotion.fill`,
    /// a linear curve exactly one tick long, so each step begins as the previous
    /// one lands and the fill reads as continuous movement rather than a
    /// staircase. Driving it at display rate would redraw sixty times for the
    /// same second of digits and buy nothing the animation does not already give.
    ///
    /// It sleeps to the next whole second of *remaining* time rather than for a
    /// flat second, and that is what keeps the promise above. The displayed
    /// value is `ceil(remaining)`, so a whole second is the instant the digits
    /// change; sleeping a fixed interval instead lets scheduling slop pile up
    /// until a tick spans nearly two seconds, and the area then animates a
    /// double-height step over a one-second curve — a visible lurch about once
    /// a minute. Deriving the wait from the remaining time absorbs the slop on
    /// every tick instead of accumulating it.
    ///
    /// The value is read from `Date.now` on every tick and never counted: a
    /// device that slept through a minute of ticks comes back a minute further
    /// on, not a minute behind.
    private func run(phase: CountdownTimer.Phase) async {
        // Even a page that is not running settles once on arrival. A run can
        // expire while this task is suspended or the page is off-screen, and
        // the phase it comes back with has to be the one the time says.
        now = .now
        timer.commitTransitions(at: now)

        guard phase == .running else { return }

        while !Task.isCancelled {
            let instant = Date.now
            now = instant
            // Written back rather than only read, so the finish is persisted in
            // the value and the task ends with the phase it produced.
            timer.commitTransitions(at: instant)

            let frame = timer.snapshot(at: instant)
            guard frame.phase == .running else {
                // The one place the finish is observed. Everything inside a
                // scaffold slot is built twice and would play the tone twice,
                // and `.task(id:)` restarting on the new phase is a rebuild,
                // not a transition — a run that ends while this screen is off
                // to one side would sound on arrival rather than at zero.
                //
                // A finish reached while the app is in the background is
                // silent: Loop declares no audio background mode, so iOS has
                // suspended it. The timer is unaffected — it derives from
                // `Date` — and the tone fires on return instead.
                if frame.phase == .finished {
                    LoopSounds.play(.timerFinished, enabled: settings.sound)
                }
                return
            }

            // A remaining time that has just landed on a whole second waits a
            // full one for the next, rather than spinning on a zero sleep.
            let untilNextSecond = frame.remaining.truncatingRemainder(dividingBy: LoopMotion.tickInterval)
            try? await Task.sleep(for: .seconds(untilNextSecond > 0 ? untilNextSecond : LoopMotion.tickInterval))
        }
    }
}

// MARK: - Setup

/// The idle state: the duration as a large preview, and the scale that sets it.
///
/// Its own view rather than a branch inside the screen, so the ink is read here,
/// at the leaf. `FillSurface` injects the per-layer ink from inside the scaffold;
/// a read above it would get the environment's default and one of the two layers
/// would be drawn in the wrong tone.
private struct CountdownSetup: View {

    let time: String

    @Binding var minutes: Int

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopInk) private var ink

    var body: some View {
        VStack(spacing: metrics.countdownIdleSpacing) {
            Text(verbatim: time)
                .loopTextStyle(typography.countdownPreview)
                .monospacedDigit()
                .foregroundStyle(ink.base)
                .frame(maxWidth: .infinity)

            ScaleSlider(
                label: LoopStrings.duration,
                minutes: $minutes,
                detents: Self.detents,
                numberEvery: LoopMetrics.durationNumberInterval,
                unit: LoopStrings.minutesUnit
            )
        }
        // Centred in the space the scaffold gives it, and without the −30 pt
        // offset the running states carry: the export draws the idle page as
        // its own layout, with the preview and the scale sharing the middle.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Which values the scale may come to rest on, and how far it runs.
    ///
    /// Handed over from the engine rather than described here. How long a
    /// countdown may be, and whether a given minute is selectable, is a rule
    /// about the timer — staged one-minute detents below two hours and
    /// five-minute ones above, up to thirty hours — and it lives in
    /// `LoopTimerLimits` where a test reaches it without a simulator.
    /// `ScaleDetents` is only the shape the drawing needs, so neither this
    /// screen nor the design layer keeps a second opinion about the range.
    private static let detents = ScaleDetents(
        range: LoopTimerLimits.duration.range,
        nearest: { LoopTimerLimits.duration.nearest(to: $0) },
        next: { LoopTimerLimits.duration.next(after: $0) },
        previous: { LoopTimerLimits.duration.previous(before: $0) }
    )
}

// MARK: - Preview

#Preview {
    CountdownScreen()
        .environment(LoopSettings(defaults: UserDefaults(suiteName: "preview") ?? .standard))
}
