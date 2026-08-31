import SwiftUI

// MARK: - Navigation dots

/// The five dots at the bottom of every page — the app's only navigation
/// affordance and the only thing that says which page is showing.
///
/// Drawn by the shell rather than by each screen: the dots sit inside the same
/// content that `FillSurface` renders twice, so they pick up the two-tone edge
/// for free and no screen has to remember to add them.
struct NavigationDots: View {

    let count: Int
    let currentIndex: Int

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopInk) private var ink

    var body: some View {
        HStack(spacing: metrics.dotSpacing) {
            ForEach(0..<count, id: \.self) { index in
                let isCurrent = index == currentIndex
                let size = isCurrent ? metrics.activeDotSize : metrics.inactiveDotSize

                Circle()
                    .fill(ink.base)
                    .opacity(isCurrent ? 1 : LoopMetrics.inactiveDotOpacity)
                    .frame(width: size, height: size)
            }
        }
        // The row keeps the height of the largest dot, so the line does not
        // shift by half a point as the active dot moves.
        .frame(height: metrics.activeDotSize)
        .padding(.top, metrics.dotsTopPadding)
        .accessibilityHidden(true)
    }
}
