import SwiftUI

// MARK: - Count-up

/// A stopwatch. No rising area either: without a total there is no fraction to
/// fill, and the export leaves the page flat on purpose.
///
/// Three states, and the whole page follows from the phase: `00:00` and "ready"
/// before a run, the elapsed time and "since 09:29" during it, the frozen time
/// and "on hold" while it is held. The pill says "paused" in that last state
/// rather than "on hold" — the export uses two different words there, one for
/// the state the timer is in and one for what has happened to the time, and
/// collapsing them would draw the same word twice on one screen.
struct CountUpScreen: View {

    /// The timer itself. It lives here rather than in a slot of the scaffold —
    /// the slots are built twice, and two stopwatches pretending to be one
    /// would drift apart the moment either was touched.
    @State private var timer = CountUpTimer()

    /// The instant the page is currently drawn for.
    ///
    /// Every displayed value is derived from this and from `Date.now` at the
    /// tick that set it, never from a count of how many ticks have happened.
    /// A counter would drift, and would stop being true across a sleep or a
    /// spell in the background; a stored instant survives both.
    @State private var now = Date.now

    var body: some View {
        // One snapshot for the whole frame. Asking the timer for its phase,
        // its elapsed time and its start date separately would ask three
        // times, each with its own idea of "now", and the three answers could
        // disagree at a second boundary.
        let frame = timer.snapshot(at: now)

        return PageScaffold {
            StatusPill(label: LoopStrings.countUp, detail: detail(for: frame.phase))
        } content: {
            TimeDisplay(
                time: LoopTimeFormat.elapsed(frame.elapsed),
                secondary: secondary(for: frame)
            )
        } controls: {
            ControlRow(
                primary: primary(for: frame.phase),
                // Reset is drawn in every state and dead before a run has
                // begun, exactly as the export has it — a button that vanished
                // would move the row the first time the stopwatch was started.
                secondary: .init(LoopStrings.reset, isEnabled: frame.phase != .idle) {
                    timer.reset()
                }
            )
        }
        // The ticker sits outside the scaffold's slots. Anything reacting to a
        // value inside one is installed on both copies of that slot and fires
        // from both, which here would be two tickers racing to set `now`.
        .task(id: frame.phase) { await tick() }
    }

    // MARK: - Ticking

    /// Redraws the page once per displayed second while the stopwatch runs.
    ///
    /// Keyed on the phase, so it starts when a run starts and is cancelled when
    /// one is paused or reset: an idle or held stopwatch shows a value that
    /// cannot change, and waking every second to redraw it would cost battery
    /// for nothing.
    ///
    /// It sleeps to the next whole second of *elapsed* time rather than for a
    /// flat second. The displayed value is `floor(elapsed)`, so that is the
    /// instant the digits actually change; a fixed interval would drift away
    /// from it and the display would flip late by a growing margin.
    private func tick() async {
        while !Task.isCancelled {
            let instant = Date.now
            let frame = timer.snapshot(at: instant)
            guard frame.phase == .running else { return }

            now = instant

            let untilNextSecond = 1 - frame.elapsed.truncatingRemainder(dividingBy: 1)
            try? await Task.sleep(for: .seconds(untilNextSecond))
        }
    }

    // MARK: - The three states

    /// The dimmed second half of the status pill. Idle carries none — the
    /// export writes a bare "Count-up" before a run.
    private func detail(for phase: CountUpTimer.Phase) -> LocalizedStringResource? {
        switch phase {
        case .idle: return nil
        case .running: return LoopStrings.running
        case .paused: return LoopStrings.pausedDetail
        }
    }

    /// The line under the time.
    private func secondary(for frame: CountUpTimer.Snapshot) -> LocalizedStringResource {
        switch frame.phase {
        case .idle:
            LoopStrings.ready
        case .running:
            // The start date is only ever `nil` while idle, so the fallback is
            // unreachable; it is here because a crash is not the right answer
            // to a line of text.
            frame.startDate.map { LoopStrings.since(startTime(of: $0)) } ?? LoopStrings.ready
        case .paused:
            LoopStrings.onHold
        }
    }

    /// The wall-clock time a run began, without seconds — the export writes
    /// "since 09:29", a minute-precise mark rather than a second reading.
    private func startTime(of date: Date) -> String {
        LoopTimeFormat.wallClock(date, showSeconds: false)
    }

    /// The left-hand button: it begins, holds or continues the run.
    ///
    /// `start` and `resume` are separate calls on the timer, so the button
    /// picks the one its state means rather than leaving the engine to guess.
    private func primary(for phase: CountUpTimer.Phase) -> ControlRow.Item {
        switch phase {
        case .idle:
            .init(LoopStrings.start) { withCurrentInstant { timer.start(at: $0) } }
        case .running:
            .init(LoopStrings.pause) { withCurrentInstant { timer.pause(at: $0) } }
        case .paused:
            .init(LoopStrings.resume) { withCurrentInstant { timer.resume(at: $0) } }
        }
    }

    /// Runs a change against a single instant and draws the page for that same
    /// instant, so the tap does not land at one time and redraw at another.
    private func withCurrentInstant(_ change: (Date) -> Void) {
        let instant = Date.now
        change(instant)
        now = instant
    }
}

#Preview {
    CountUpScreen()
}
