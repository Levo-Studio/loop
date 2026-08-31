import SwiftUI

// MARK: - Page scaffold

/// The frame every page is drawn in: the rising fill behind everything, the
/// status pill at the top, the flexible middle, the controls, and the navigation
/// dots at the bottom.
///
/// The dots live here rather than in the screens for two reasons. They belong to
/// the shell — a screen has no business knowing which of five it is — and they
/// cross the fill edge, so they have to sit inside the content that
/// `FillSurface` renders twice. A screen that drew its own would be one tone
/// short.
///
/// A screen writes its slots once, and the two-tone edge, the safe area and the
/// content column all happen here.
///
/// ## Your closures are called twice — read this before writing a screen
///
/// "Written once" is about the source, not about how often it runs. To draw
/// the two-tone edge, `FillSurface` builds the whole of `status`, `content`
/// and `controls` **twice**: once in ink over the background, once in the
/// on-fill tone clipped to the rising area. Both copies exist at the same
/// time, at different positions in the view tree, so they have separate
/// identities and separate storage. Two rules follow, and neither can be
/// enforced by the compiler:
///
/// - **No `@State` inside a slot.** It exists twice and the copies drift apart
///   the moment one is touched — the visible half of a control would move and
///   the clipped half would not. Declare it on the screen, above the scaffold,
///   and pass a `Binding` in. One value read twice is exactly right; two
///   values pretending to be one is the bug.
/// - **Nothing inside a slot may react to a value changing.** `.onChange`,
///   `.task`, `.onReceive` and `.sensoryFeedback` are installed on both copies
///   and fire from both — a doubled haptic, a doubled timer, a side effect run
///   twice. Put them on the screen outside the scaffold, or fire them from the
///   gesture handler as `ScaleSlider` and `LoopStepper` do.
///
/// Only one of the two copies takes hit tests, so buttons and drags are safe:
/// a tap is handled once.
struct PageScaffold<Status: View, Content: View, Controls: View>: View {

    /// How full the rising area is, and which block it is measuring.
    ///
    /// Defaults to `.none`, which draws no area at all — the right value for
    /// the clock, the count-up and every setup, idle and stopped state, where
    /// there is no block duration to measure against and so no progress to
    /// show. Never a resting height, never a tint.
    ///
    /// A screen with a running block passes `FillProgress(fraction:block:)`.
    /// There is no way to give a fraction without naming its block, and that
    /// is deliberate: the block is what tells the area to jump at a boundary
    /// instead of sliding backwards over a second.
    var fill: FillProgress = .none

    /// The status pill, centred at the top. Built twice — see the note above.
    @ViewBuilder let status: () -> Status

    /// The middle of the page, given all the height left over. Built twice —
    /// see the note above.
    @ViewBuilder let content: () -> Content

    /// The control row above the navigation dots. Built twice — see the note
    /// above.
    @ViewBuilder let controls: () -> Controls

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopSafeAreaInsets) private var safeAreaInsets
    @Environment(\.loopPage) private var page

    var body: some View {
        FillSurface(progress: fill) {
            VStack(spacing: 0) {
                // The pill is centred in the export; an empty status slot
                // collapses to nothing, so the settings page keeps its layout.
                status()
                    .frame(maxWidth: .infinity)

                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                controls()
                    .frame(maxWidth: .infinity)

                NavigationDots(count: LoopPage.allCases.count, currentIndex: page.rawValue)
            }
            .frame(maxWidth: metrics.contentColumnWidth ?? .infinity)
            .frame(maxWidth: .infinity)
            .padding(pagePadding)
        }
    }

    /// The design padding, widened where a device's safe area needs more.
    ///
    /// The export is drawn on a bare rectangle: 48 pt from the top edge of a
    /// 805 pt screen, with no status bar in the way. On a real device the
    /// status bar is deeper than that, so the padding is taken as a floor
    /// rather than as an exact number — where the design already clears the
    /// hardware the drawing is untouched, and where it does not the content
    /// moves out of the way instead of under a notch.
    private var pagePadding: EdgeInsets {
        let design = metrics.pagePadding
        return EdgeInsets(
            top: max(design.top, safeAreaInsets.top),
            leading: max(design.leading, safeAreaInsets.leading),
            bottom: max(design.bottom, safeAreaInsets.bottom),
            trailing: max(design.trailing, safeAreaInsets.trailing)
        )
    }
}
