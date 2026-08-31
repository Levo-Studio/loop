import SwiftUI
import WidgetKit

// MARK: - Time

/// The remaining time, counted by iOS rather than by an update.
///
/// `Text(timerInterval:pauseTime:countsDown:showsHours:)` is the whole reason
/// this Live Activity needs no per-second push. The system re-renders the digits
/// inside the window on its own, and a `pauseTime` freezes them where the run
/// was held — which is the difference between a paused timer and the one
/// everybody ships, that keeps counting on the lock screen after the user
/// stopped it.
struct LoopActivityTime: View {

    let state: LoopActivityAttributes.ContentState
    let style: LoopTextStyle

    var body: some View {
        Text(
            timerInterval: state.window,
            pauseTime: state.pausedAt,
            countsDown: true,
            showsHours: state.showsHours
        )
        .loopTextStyle(style)
        .monospacedDigit()
    }
}

// MARK: - Progress

/// The rising area, as far as a system surface allows one.
///
/// Loop has exactly one progress indicator and it is an area that rises from the
/// bottom edge. A Live Activity cannot draw it: the only progress iOS animates
/// without an update is `ProgressView(timerInterval:)`, and it animates it for
/// the built-in styles only — a custom `ProgressViewStyle` is handed a `nil`
/// `fractionCompleted` and would have to be driven by a push every second. So
/// the area is kept as the accent fill and flattened into the band the system
/// will move, flush against the bottom edge where the app's fill begins.
///
/// A held run is drawn from `pausedFraction` instead. `ProgressView` has no
/// `pauseTime`, so a running one left in place would keep rising under digits
/// that had already stopped.
struct LoopActivityProgress: View {

    let state: LoopActivityAttributes.ContentState

    @Environment(\.loopPalette) private var palette

    var body: some View {
        Group {
            if state.isPaused {
                ProgressView(value: state.pausedFraction)
            } else {
                // `countsDown: false` so the bar rises with elapsed time, the
                // direction the app's area moves in.
                ProgressView(timerInterval: state.window, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            }
        }
        .progressViewStyle(.linear)
        .tint(palette.fill)
        .frame(height: LoopActivityMetrics.progressHeight)
    }
}

// MARK: - Status

/// The pill from the app: the block, and the round counter beside it on an
/// interval.
struct LoopActivityStatus: View {

    let state: LoopActivityAttributes.ContentState

    var body: some View {
        StatusPill(label: label, detail: detail)
    }

    private var label: LocalizedStringResource {
        switch state.block {
        case .countdown: LoopStrings.countdown
        case .focus: LoopStrings.focus
        case .rest: LoopStrings.breakBlock
        }
    }

    /// The countdown has no rounds, so it has no detail — the pill is the page
    /// name alone, exactly as on the screen.
    private var detail: LocalizedStringResource? {
        state.block == .countdown
            ? nil
            : LoopStrings.roundCounter(current: state.round, total: state.rounds)
    }
}

// MARK: - Accent mark

/// The pill's dot on its own, for the compact Dynamic Island where there is no
/// room for the pill. It names the accent, which is the one thing the compact
/// presentation can carry of Loop's look.
struct LoopActivityMark: View {

    @Environment(\.loopPalette) private var palette
    @Environment(\.loopMetrics) private var metrics

    var body: some View {
        Circle()
            .fill(palette.marker)
            .frame(width: metrics.pillDotSize, height: metrics.pillDotSize)
    }
}
