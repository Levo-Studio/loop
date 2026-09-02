import SwiftUI

// MARK: - Navigation strip

/// Where the strip of pages stands, read from one page, and what that makes of
/// the five dots.
///
/// Split out of the view because this is the half that can be wrong: the sign
/// of the travel, the clamp that keeps the rubber band at the first and last
/// page from shrinking the active dot, and the weights adding up to one so the
/// row keeps the width the export draws. Two rectangles in and a few numbers
/// out is testable without a simulator; the same arithmetic spread across a
/// `body` is not.
nonisolated struct NavigationStrip: Equatable, Sendable {

    /// How many pages there are.
    let count: Int

    /// The page this reading was taken on — not the page that is showing.
    let index: Int

    /// The page's rectangle in the row's own coordinates, or `null` while
    /// nothing has been measured yet.
    let window: CGRect

    /// How far the strip has travelled away from this page, in points, and so
    /// how far the row has to move to stay where it was drawn. Positive while
    /// the pages to the right are coming in.
    let shift: CGFloat

    /// The same travel counted in pages.
    let travel: Double

    /// - Parameters:
    ///   - page: the page's rectangle in the row's coordinates.
    ///   - visible: the scroll view's visible rectangle in the same
    ///     coordinates. The difference between the two left edges is the whole
    ///     measurement: it is zero exactly when this page is the one on screen,
    ///     whatever the padding around the row does, and it grows by a page
    ///     width for every page the strip travels.
    init(count: Int, index: Int, page: CGRect, visible: CGRect) {
        self.count = count
        self.index = index

        guard !page.isNull, !visible.isNull, page.width > 0 else {
            self.window = .null
            self.shift = 0
            self.travel = 0
            return
        }

        self.window = page
        self.shift = visible.minX - page.minX
        self.travel = Double(self.shift / page.width)
    }

    /// Where the strip stands, as a page index — fractional in the middle of a
    /// swipe.
    ///
    /// Clamped to the ends because the paging scroll view bounces past them:
    /// without the clamp a pull at the first page would fade the dot that is
    /// unambiguously current, which reads as a glitch rather than as the
    /// elastic it is answering.
    var position: Double {
        min(max(Double(index) + travel, 0), Double(count - 1))
    }

    /// How much of the active state a dot holds, from 1 when the strip stands
    /// on it to 0 a whole page away.
    ///
    /// The weights of two neighbours always add to one, which is what keeps the
    /// row exactly as wide mid-swipe as the export draws it at rest: the size a
    /// dot gains is the size the one beside it gives up.
    ///
    /// **The share is eased, and that is the whole difference between an
    /// indicator and a smear.** Straight off the scroll offset, the middle
    /// third of every swipe puts two dots at around 60 % — neither of them
    /// readable as the current page, on the one row that is the app's only
    /// answer to where you are. Eased, the row holds its answer for most of the
    /// gesture and changes it quickly through the middle, while still moving at
    /// every point of the swipe rather than flipping once at the halfway mark.
    ///
    /// Smoothstep specifically, because it is symmetric about its midpoint:
    /// `f(t) + f(1 − t)` is exactly 1, so easing costs nothing of the width
    /// above and every resting value stays the export's.
    func weight(of dot: Int) -> Double {
        let share = max(0, 1 - abs(position - Double(dot)))
        return share * share * (3 - 2 * share)
    }
}

// MARK: - Navigation dots

/// The five dots at the bottom of every page — the app's only navigation
/// affordance and the only thing that says which page is showing.
///
/// Drawn by the shell rather than by each screen: the dots sit inside the same
/// content that `FillSurface` renders twice, so they pick up the two-tone edge
/// for free and no screen has to remember to add them.
///
/// ## One row per page, standing still
///
/// Every page carries a row, and each row moves against its own page by exactly
/// the distance that page has been scrolled. The result is a row that does not
/// travel with the pages: it stays where it was drawn while the strip slides
/// under it, which is what the design means by *always visible*. All five rows
/// read the same scroll position, so mid-swipe the two rows on screen are the
/// same drawing at the same place, and clipping each to its own page tiles them
/// into one — with the seam falling exactly on the page boundary.
///
/// That clip is not decoration. Two unclipped rows would overlay each other and
/// double the 30 % of an inactive dot into 51 %, and each half has to belong to
/// its own page anyway so that it picks up *that* page's fill edge for the
/// two-tone.
///
/// The active dot is not a state that flips at the halfway point. It grows and
/// fades into its neighbour across the swipe, so the highlight travels with the
/// finger instead of jumping once the gesture is already over.
struct NavigationDots: View {

    /// How many pages there are.
    let count: Int

    /// The page this row is drawn on.
    let index: Int

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopInk) private var ink

    /// The last geometry reading.
    ///
    /// `@State` inside twice-built content is normally the bug `FillSurface`
    /// warns about, and this is the one shape that cannot drift: it is derived
    /// from the layout and never from a gesture, and both copies sit at the
    /// same place in the same page, so both take the same reading on the same
    /// pass. Nothing writes it but the measurement below.
    @State private var reading = Reading()

    /// The coordinate space of a single page. `PageScaffold` names it, because
    /// the page is the frame this row has to hold still against and the scroll
    /// view's own space cannot say where one page ends.
    ///
    /// Computed rather than stored: `NamedCoordinateSpace` is not `Sendable`,
    /// and the measurement below runs in a closure that has to be. The token it
    /// is named after is what carries the identity, so building the space twice
    /// still names the same one.
    nonisolated static var pageSpace: NamedCoordinateSpace { .named(Space.page) }

    /// The token behind the space above. A type of its own rather than a
    /// string, so nothing else can name the same space by accident.
    nonisolated private enum Space: Hashable, Sendable { case page }

    var body: some View {
        let strip = NavigationStrip(count: count, index: index, page: reading.page, visible: reading.visible)

        HStack(spacing: metrics.dotSpacing) {
            ForEach(0..<count, id: \.self) { dot in
                let weight = strip.weight(of: dot)

                Circle()
                    .fill(ink.base)
                    .opacity(LoopMetrics.inactiveDotOpacity + (1 - LoopMetrics.inactiveDotOpacity) * weight)
                    .frame(width: size(at: weight), height: size(at: weight))
            }
        }
        // The row keeps the height of the largest dot, so the line does not
        // shift by half a point as the active dot moves.
        .frame(height: metrics.activeDotSize)
        .padding(.top, metrics.dotsTopPadding)
        .offset(x: strip.shift)
        .clipShape(PageWindow(rect: strip.window))
        .onGeometryChange(for: Reading.self) { proxy in
            Reading(
                page: proxy.bounds(of: Self.pageSpace) ?? .null,
                visible: proxy.bounds(of: .scrollView(axis: .horizontal)) ?? .null
            )
        } action: { reading = $0 }
        .accessibilityHidden(true)
    }

    /// A dot's diameter at a given share of the active state: the export's 6 pt
    /// at none of it and 7 pt at all of it.
    private func size(at weight: Double) -> CGFloat {
        metrics.inactiveDotSize + (metrics.activeDotSize - metrics.inactiveDotSize) * weight
    }

    // MARK: - Measurement

    /// The two rectangles the row is placed from, taken in one pass so they can
    /// never be a frame apart.
    nonisolated private struct Reading: Equatable, Sendable {
        var page: CGRect = .null
        var visible: CGRect = .null
    }

    /// The page, as something to clip to. A plain `.clipped()` would clip to
    /// the row's own bounds, which is the one rectangle that is useless here —
    /// the row is meant to leave them.
    nonisolated private struct PageWindow: Shape {

        let rect: CGRect

        func path(in bounds: CGRect) -> Path {
            // Before the first measurement the row has not moved, so its own
            // bounds clip nothing away.
            Path(rect.isNull ? bounds : rect)
        }
    }
}
