import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity

/// Loop on the lock screen and in the Dynamic Island.
///
/// One configuration for both timers. The countdown and the interval draw the
/// same three things — a pill, a remaining time and a rising progress — and the
/// only difference is that the interval's pill carries a round counter. Two
/// activity types would be two copies of the layout for one line of difference.
struct LoopActivityWidget: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LoopActivityAttributes.self) { context in
            LoopActivityLockScreen(state: context.state)
        } dynamicIsland: { context in
            let state = context.state

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LoopActivitySurface(accentID: state.accentID) {
                        LoopActivityStatus(state: state)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    LoopActivitySurface(accentID: state.accentID) {
                        LoopActivityTime(state: state, style: LoopActivityTypography.time)
                    }
                }
            } compactLeading: {
                LoopActivitySurface(accentID: state.accentID) {
                    LoopActivityMark()
                }
            } compactTrailing: {
                LoopActivitySurface(accentID: state.accentID) {
                    LoopActivityTime(state: state, style: LoopActivityTypography.compactTime)
                }
            } minimal: {
                // The minimal presentation is a circle beside another app's, so
                // it gets the accent mark rather than digits nobody could read
                // at that size.
                LoopActivitySurface(accentID: state.accentID) {
                    LoopActivityMark()
                }
            }
            .keylineTint(LoopPalette(accent: LoopAccent(rawValue: state.accentID) ?? .default, scheme: .dark).marker)
        }
    }
}

// MARK: - Lock screen

/// The card on the lock screen and in the banner.
///
/// The layout is the app's timer page with everything the page has that this
/// surface cannot carry taken out: the pill above and the time under it, the
/// same order, the same roles, the same fonts. The rising area does not come
/// with them — see the note in `LoopActivityParts.swift`.
struct LoopActivityLockScreen: View {

    let state: LoopActivityAttributes.ContentState

    var body: some View {
        LoopActivitySurface(accentID: state.accentID) {
            LockScreenBody(state: state)
        }
    }
}

// MARK: - Lock screen body

/// Split out so the background tint can read the palette that
/// `LoopActivitySurface` puts into the environment. A modifier applied outside
/// the surface would resolve the default accent instead.
private struct LockScreenBody: View {

    let state: LoopActivityAttributes.ContentState

    @Environment(\.loopPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: LoopActivityMetrics.stackSpacing) {
            LoopActivityStatus(state: state)

            LoopActivityTime(state: state, style: LoopActivityTypography.time)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LoopActivityMetrics.cardPadding)
        .activityBackgroundTint(palette.background)
        .activitySystemActionForegroundColor(palette.inkOnBackground.base)
    }
}
