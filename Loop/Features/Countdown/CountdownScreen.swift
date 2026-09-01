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
    /// answers are needed by code that is not a view at all: one decides
    /// whether the finished state rings, the other how it is dismissed, and
    /// they are independent. With sound off there is no alarm and the slide is
    /// still the only way out.
    @Environment(LoopSettings.self) private var settings

    /// The countdown, owned by the app rather than by this page. Read above the
    /// scaffold like the settings, and for one reason more: a run has to
    /// outlive this view. Held as `@State` it would be gone with the process,
    /// and a countdown that forgets it was running is the one failure a timer
    /// cannot have.
    @Environment(LoopTimers.self) private var timers

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

    /// How far the slide-to-stop knob has travelled, 0…1.
    ///
    /// Declared here rather than inside `SlideToStop`, and this is the case
    /// `PageScaffold`'s rule is actually about. A finished countdown draws a
    /// **full** area, so both of the two-tone layers are on screen at once —
    /// unlike a slider, whose second copy is masked away on a page with no
    /// fill. State inside the control would exist twice, only one copy takes
    /// touches, and the knob that moved would be the one nobody can see.
    @State private var slideProgress: Double = 0

    var body: some View {
        // One snapshot per frame. Asking the timer for the phase, then the
        // time, then the fraction would be three different instants, and one
        // landing either side of the finish shows a full area under a running
        // pill.
        let snapshot = timers.countdown.snapshot(at: now)

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
        // The alarm is a repeating cue and this screen is the only thing that
        // starts one, so it is also the only thing that can be sure it ends.
        // A page torn down while it rings would otherwise leave a task
        // sounding for a state that no longer exists.
        .onDisappear { LoopAlarm.stop() }
        // Sound off means no alarm, including one that is already ringing.
        // The switch is on another page, so this is reachable: swipe to
        // settings while it rings, turn it off, and it has to stop there
        // rather than on the next dismissal.
        .onChange(of: settings.sound) { _, isOn in
            if !isOn { LoopAlarm.stop() }
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
            set: { minutes in act { $0.setDuration(minutes: minutes, at: $1) } }
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
            if requiresSwipe {
                // The whole of the row, and Restart is gone with it. That is
                // the decision the state forces: an alarm has exactly one
                // action, which is to acknowledge it, and a live Restart
                // beside a ringing countdown is a tap that silences nothing
                // and quietly begins another twenty-five minutes. It is not
                // lost either — the slide lands on the idle state with the
                // duration untouched and Start under the thumb, so restarting
                // is one further tap on a button that is already there.
                //
                // The track is exactly as tall as the two buttons it stands
                // in for, so nothing on the page moves between the states.
                SlideToStop(label: LoopStrings.slideToStop, progress: $slideProgress) { stop() }
            } else {
                ControlRow(
                    primary: .init(LoopStrings.restart) { start() },
                    // Both live: with the setting off, the finished state is
                    // dismissed by tapping Close, and this is the row the page
                    // has always drawn there.
                    secondary: .init(LoopStrings.close) { stop() }
                )
            }
        }
    }

    // MARK: - Acting

    /// Each of these settles the frame on the same instant it hands to the
    /// engine, so the tap redraws at the time it happened rather than at the
    /// time of the last tick.
    private func start() {
        // Before the change and before the write: a restart from a ringing
        // finish has to be silent from the tap, not from the next repetition.
        LoopAlarm.stop()

        act { $0.start(at: $1) }
        run += 1
        slideProgress = 0
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
        act { $0.pause(at: $1) }
    }

    private func resume() {
        act { $0.resume(at: $1) }
    }

    private func stop() {
        LoopAlarm.stop()
        act { countdown, _ in countdown.reset() }
        // Home again for the next finish. The control is gone by the time this
        // is read, so it is reset here rather than by the animation that would
        // otherwise be running over a state that no longer exists.
        slideProgress = 0
    }

    /// Runs a change against a freshly read instant and draws the page for that
    /// same instant, so a tap does not land at one time and redraw at another.
    ///
    /// It goes through the owner rather than into a local copy: that is what
    /// puts the new state on disk, and it is the only write path there is.
    /// The instant is handed back for the tick, which draws the lock screen
    /// from the same frame it just settled.
    @discardableResult
    private func act(_ change: (inout CountdownTimer, Date) -> Void) -> Date {
        let instant = Date.now
        timers.update(\.countdown) { change(&$0, instant) }
        now = instant
        return instant
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
        act { $0.commitTransitions(at: $1) }

        guard phase == .running else { return }

        while !Task.isCancelled {
            // Written back rather than only read, so the finish is persisted in
            // the value and the task ends with the phase it produced.
            let instant = act { $0.commitTransitions(at: $1) }
            let frame = timers.countdown.snapshot(at: instant)
            // The lock screen and the Dynamic Island, off the same snapshot the
            // tick already has. Called every tick rather than on a transition:
            // the controller pushes only when something it shows has moved, and
            // a second opinion about that here would be the copy that is wrong.
            // It sees the finished frame too, which is what ends the Activity.
            LoopActivityController.shared.update(countdown: frame, accent: settings.accent, at: instant)

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
                    // An alarm rather than the single cue this used to play:
                    // one tone that sounds once and stops is a notification,
                    // and a countdown set to run out at a particular moment
                    // has to still be asking when someone reaches the room.
                    // It rings until the finished state is dismissed, or
                    // for a quarter of an hour, whichever comes first — and
                    // going quiet on the limit changes nothing here: the
                    // state is still finished and still waiting to be
                    // acknowledged.
                    LoopAlarm.start(enabled: settings.sound)
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
                minuteScale: LoopTimerLimits.duration,
                numberEvery: LoopMetrics.countdownNumberInterval,
                unit: LoopStrings.minutesUnit
            )
        }
        // Centred in the space the scaffold gives it, and without the −30 pt
        // offset the running states carry: the export draws the idle page as
        // its own layout, with the preview and the scale sharing the middle.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    CountdownScreen()
        .environment(LoopSettings(defaults: UserDefaults(suiteName: "preview") ?? .standard))
        .environment(LoopTimers(store: TimerStateStore(defaults: UserDefaults(suiteName: "preview") ?? .standard)))
}
