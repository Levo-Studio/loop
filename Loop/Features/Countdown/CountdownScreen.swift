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

    /// The timer itself. A value, not an observable object — the engine holds no
    /// view and publishes nothing; a new frame comes from `now` moving.
    @State private var timer = CountdownTimer()

    /// The instant the current frame is drawn at. Every displayed value is
    /// derived from it, so the phase, the time and the area can never disagree
    /// about what time it is.
    @State private var now = Date.now

    var body: some View {
        // One snapshot per frame. Asking the timer for the phase, then the
        // time, then the fraction would be three different instants, and one
        // landing either side of the finish shows a full area under a running
        // pill.
        let snapshot = timer.snapshot(at: now)

        PageScaffold(fillFraction: snapshot.fraction) {
            pill(for: snapshot)
        } content: {
            content(for: snapshot)
        } controls: {
            controls(for: snapshot)
        }
        // The tick sits on the screen rather than in a slot, because a slot is
        // built twice and would run two of them.
        .task(id: snapshot.phase) { await run(phase: snapshot.phase) }
    }

    // MARK: - Status

    @ViewBuilder private func pill(for snapshot: CountdownTimer.Snapshot) -> some View {
        switch snapshot.phase {
        case .idle, .running:
            StatusPill(label: LoopStrings.countdown)
        case .paused:
            // "Countdown · paused": the page keeps its name and the state is a
            // dimmed qualifier after it.
            StatusPill(label: LoopStrings.countdown, detail: LoopStrings.paused)
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
            CountdownSetup(time: LoopTimeFormat.remaining(snapshot.duration), minutes: durationMinutes)
        case .running:
            TimeDisplay(
                time: LoopTimeFormat.remaining(snapshot.remaining),
                secondary: LoopStrings.ofDuration(LoopTimeFormat.remaining(snapshot.duration))
            )
        case .paused:
            TimeDisplay(time: LoopTimeFormat.remaining(snapshot.remaining), secondary: LoopStrings.paused)
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
    private var durationMinutes: Binding<Int> {
        Binding(
            get: { timer.durationMinutes },
            set: { minutes in
                let instant = Date.now
                timer.setDuration(minutes: minutes, at: instant)
                now = instant
            }
        )
    }

    // MARK: - Controls

    @ViewBuilder private func controls(for snapshot: CountdownTimer.Snapshot) -> some View {
        switch snapshot.phase {
        case .idle:
            ControlRow(
                primary: .init(LoopStrings.start, isEnabled: timer.canStart) { start() },
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
                secondary: .init(LoopStrings.close) { stop() }
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
    /// The value is read from `Date.now` on every tick and never counted: a
    /// device that slept through a minute of ticks comes back a minute further
    /// on, not a minute behind.
    private func run(phase: CountdownTimer.Phase) async {
        // Even a page that is not running settles once on arrival — a stored
        // run may have finished while the app was away.
        now = .now
        timer.commitTransitions(at: now)

        guard phase == .running else { return }

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(LoopMotion.tickInterval))
            guard !Task.isCancelled else { return }

            now = .now
            // Written back rather than only read, so the finish is persisted in
            // the value and the task ends with the phase it produced.
            timer.commitTransitions(at: now)
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
                maximumMinutes: LoopTimerLimits.durationMinutes.upperBound,
                numberEvery: Self.numberEvery,
                unit: LoopStrings.minutesUnit
            )
        }
        // Centred in the space the scaffold gives it, and without the −30 pt
        // offset the running states carry: the export draws the idle page as
        // its own layout, with the preview and the scale sharing the middle.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// A number under the scale every quarter of the hour — 0, 15, 30, 45, 60.
    ///
    /// It belongs beside `sliderMajorTickInterval` in `LoopMetrics`, next to the
    /// tick spacing it is a multiple of; the interval page needs the same value
    /// and a second scale that prints every ten. Named here rather than written
    /// into the call so there is one place to delete when it moves.
    private static let numberEvery = 15
}

// MARK: - Preview

#Preview {
    CountdownScreen()
}
