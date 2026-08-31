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
/// A screen writes its content once. The two-tone edge, the safe area and the
/// iPad content column all happen here.
struct PageScaffold<Status: View, Content: View, Controls: View>: View {

    /// How full the rising area is, 0…1. Pages without a duration — clock,
    /// count-up, every setup state — leave it at zero and get no area at all.
    var fillFraction: Double = 0

    @ViewBuilder let status: () -> Status
    @ViewBuilder let content: () -> Content
    @ViewBuilder let controls: () -> Controls

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopSafeAreaInsets) private var safeAreaInsets
    @Environment(\.loopPage) private var page

    var body: some View {
        FillSurface(fraction: fillFraction) {
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
