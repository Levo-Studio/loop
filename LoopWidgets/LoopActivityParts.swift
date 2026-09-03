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

    /// The room to reserve, or `nil` where the surface gives the text a width
    /// of its own.
    ///
    /// Only the compact Dynamic Island passes one, and it has to: a compact
    /// slot sizes to its content, and this text has none to size to. See
    /// `LoopActivityTypography.compactTimeWidth(characters:)`.
    var width: CGFloat?

    var body: some View {
        Text(
            timerInterval: state.window,
            pauseTime: state.pausedAt,
            countsDown: true,
            showsHours: state.showsHours
        )
        .loopTextStyle(style)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(LoopActivityTypography.timeMinimumScale)
        .frame(width: width)
    }
}

// MARK: - Progress

// There is deliberately no progress view here.
//
// Loop has exactly one progress indicator and it is an area that rises from the
// bottom edge. A Live Activity cannot draw it: the only progress iOS animates
// without an update is `ProgressView(timerInterval:)`, and it animates it for
// the built-in styles only — a custom `ProgressViewStyle` is handed a `nil`
// `fractionCompleted`, so an area shaped like Loop's would have to be driven by
// a push every second. ActivityKit throttles those and drops the ones over
// budget, which would spend the budget on frames that look identical and leave
// none for the block boundary that matters.
//
// A plain system bar was tried and taken out again: the rising area is the
// app's, and a band that is not it is a second progress indicator rather than a
// smaller version of the first. The lock screen shows the time, and on an
// interval the block and the round. That is the whole card.
//
// So: if you are about to add a `ProgressView` back, this is what it costs.

// MARK: - Status

/// The pill from the app: the block, the round counter beside it on an interval,
/// and on a held run the page's own way of saying so.
///
/// **A held card says it in words, and the words are the page's.** The digits
/// cannot say it: `Text(pauseTime:)` freezes them, and frozen digits are exactly
/// what a stopped timer shows too, so a card without the pill saying it leaves
/// the two states looking identical. Both wordings are lifted from the screens
/// rather than invented here, so the card reads as the page it mirrors.
struct LoopActivityStatus: View {

    let state: LoopActivityAttributes.ContentState

    var body: some View {
        StatusPill(label: label, detail: detail)
    }

    /// A held interval gives the label to "Paused" and moves the block down
    /// into the detail, exactly as the interval page does. A held countdown
    /// does not: it has no round for the detail to carry, so the page keeps its
    /// name in the label and puts "paused" beside it.
    private var label: LocalizedStringResource {
        state.isPaused && state.block != .countdown ? LoopStrings.pausedStatus : blockName
    }

    private var detail: LocalizedStringResource? {
        guard state.block != .countdown else {
            // The countdown has no rounds, so a running card's pill is the page
            // name on its own, exactly as on the screen.
            return state.isPaused ? LoopStrings.pausedDetail : nil
        }

        return state.isPaused
            ? LoopStrings.blockAndRound(blockName, current: state.round, total: state.rounds)
            : LoopStrings.roundCounter(current: state.round, total: state.rounds)
    }

    /// The block's own name, which is the pill's label while a run goes and
    /// moves into the detail while an interval is held.
    private var blockName: LocalizedStringResource {
        switch state.block {
        case .countdown: LoopStrings.countdown
        case .focus: LoopStrings.focus
        case .rest: LoopStrings.breakBlock
        }
    }
}

// MARK: - Accent mark

/// The pill's dot on its own, for the compact and minimal Dynamic Island where
/// there is no room for the pill. It names the accent, which is the one thing
/// those two presentations can carry of Loop's look.
///
/// The size is given rather than taken from `LoopMetrics.pillDotSize`: that
/// value is measured against the pill's 11 pt label, and neither island slot
/// has one. See `LoopActivityMetrics`.
struct LoopActivityMark: View {

    let size: CGFloat

    /// Whether the run behind the card is held.
    ///
    /// **This is the whole of what the compact and minimal presentations can
    /// say about it.** The compact island has room for a mark and a time and
    /// nothing else, and the time cannot carry the state: iOS freezes the
    /// digits at the held instant, and a stopped run prints frozen digits too.
    /// The minimal presentation has no time at all. So the mark takes it on,
    /// and it changes shape rather than colour — colour is what names the
    /// accent here, and a mark that changed it would say "held" by dropping the
    /// one thing these two presentations carry of Loop's look.
    var isPaused: Bool = false

    @Environment(\.loopPalette) private var palette

    var body: some View {
        Group {
            if isPaused {
                HStack(spacing: size * LoopActivityMetrics.pauseBarGapRatio) {
                    bar
                    bar
                }
            } else {
                Circle()
                    .fill(palette.marker)
            }
        }
        // Both marks are drawn in the dot's own box, so the compact island
        // keeps its width when a run is held. See `pauseBarWidthRatio`.
        .frame(width: size, height: size)
    }

    /// A capsule rather than a rectangle: it is the dot's own roundness at a
    /// different aspect, so the two marks read as one drawing in two states.
    private var bar: some View {
        Capsule()
            .fill(palette.marker)
            .frame(width: size * LoopActivityMetrics.pauseBarWidthRatio)
    }
}

// MARK: - Body

/// The pill above the time: the app's timer page, with everything this surface
/// cannot carry taken out — the rising area does not come with them, see the
/// note above.
///
/// Shared by the lock screen and the expanded Dynamic Island, which draw the
/// same two things at the same sizes. One view rather than two so they cannot
/// drift apart.
struct LoopActivityBody: View {

    let state: LoopActivityAttributes.ContentState

    @Environment(\.loopTypography) private var typography

    var body: some View {
        VStack(alignment: .leading, spacing: LoopActivityMetrics.stackSpacing) {
            LoopActivityStatus(state: state)

            VStack(alignment: .leading, spacing: LoopActivityMetrics.heldLineSpacing) {
                LoopActivityTime(state: state, style: LoopActivityTypography.time)

                if state.isPaused {
                    // The page's second word for being held, under the time
                    // where the page puts it. The pill above already says
                    // "paused", and the export draws two different words for
                    // exactly that reason — one names the state, this one says
                    // what has happened to the time.
                    Text(LoopStrings.onHold)
                        .loopTextStyle(typography.secondaryLine)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
