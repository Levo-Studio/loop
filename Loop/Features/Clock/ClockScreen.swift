import SwiftUI

// MARK: - Clock

/// The current time, with seconds when the setting asks for them. No controls
/// and no rising area — the clock has no duration, so there is no progress to
/// show and nothing to steer.
///
/// The page is a pure function of one instant: `TimelineView` hands in the
/// moment to draw and everything below is derived from it. Nothing here counts
/// ticks, and nothing here stores the time it last showed — a display that
/// accumulated would drift, and a clock is the one screen where a drift of a
/// second is visible to anyone glancing at it.
///
/// ## It ticks while it is off screen, and that is the decision
///
/// The pages are an `HStack` in a paging scroll view, so all five are realised
/// for as long as the app runs and this one goes on waking once a second while
/// the user sits on Interval — measured at fifteen ticks over fifteen seconds,
/// eight of them with the clock nowhere near the screen. It was a `LazyHStack`
/// and made no difference to that: lazy only ever governed the first build, and
/// after one pass through the strip all five stayed realised anyway.
///
/// It is not gated, and not for want of trying:
///
/// - `\.loopPage` cannot answer the question. It carries the identity of the
///   page a view is drawn *inside*, which in here is always `.clock`; the shell
///   gives every page its own, so the navigation dots can each draw themselves
///   as current. The selected page lives in `RootShell`'s scroll position.
/// - `onScrollVisibilityChange` does fire correctly — `true` at launch, `false`
///   on leaving, `true` on returning. But driving the schedule from it changed
///   nothing: an exhausted `TimelineSchedule` does not stop a `TimelineView`,
///   which falls back to a cadence of its own. The same fifteen ticks, plus
///   three more from the rebuilds the gate itself caused.
///
/// So the gate was removed rather than left in looking like it worked. The cost
/// is one page rebuild a second on a screen with no animation and no fill; the
/// alternative on offer was the same cost plus a state variable, a schedule
/// flag and a way for the clock to freeze if visibility is ever misreported.
/// Backgrounding is already handled — SwiftUI stops the `TimelineView` about
/// two seconds after the app goes behind, which is the case that actually costs
/// something.
struct ClockScreen: View {

    @Environment(LoopSettings.self) private var settings

    var body: some View {
        // The schedule sits outside the scaffold's slots, which is where every
        // reacting thing has to live: `FillSurface` builds `status`, `content`
        // and `controls` twice, and a tick installed inside one of them would
        // run twice per second for one visible clock.
        TimelineView(WallClockSchedule(period: cadence)) { context in
            let face = ClockFace(date: context.date, showSeconds: settings.showSeconds)

            PageScaffold {
                StatusPill(label: LoopStrings.clock)
            } content: {
                ClockTimeBlock(face: face)
            } controls: {
                // No buttons on this page. The slot stays empty and the fill
                // fraction stays at its default zero.
                EmptyView()
            }
        }
        // A `TimelineSchedule` is not `Equatable`, so a `TimelineView` handed a
        // new one is not obliged to throw the running schedule away. Turning
        // seconds on while the minute cadence was in force would then leave the
        // seconds frozen for up to a minute. Identity by cadence makes the
        // change a rebuild instead of a hope.
        .id(cadence)
    }

    // MARK: - Cadence

    /// How often the page is rebuilt.
    ///
    /// With seconds shown the display changes every second, so it ticks every
    /// second. With them hidden it changes only on the minute, and a per-second
    /// rebuild would redraw the whole two-layer page sixty times for one visible
    /// change — the clock is a page people leave open, so that is worth
    /// avoiding rather than tolerating. The schedule lands on the boundary
    /// either way, so the slower cadence flips the minute on time instead of up
    /// to fifty-nine seconds late.
    private var cadence: TimeInterval {
        settings.showSeconds ? WallClockSchedule.second : WallClockSchedule.minute
    }
}

// MARK: - Time block

/// The big time over the weekday and date.
///
/// A view of its own rather than a closure, because the ink has to be read
/// *here*. `FillSurface` injects the per-layer `LoopInk` from inside itself, so
/// a read anywhere above `PageScaffold` gets the environment default and both
/// tones come out the same colour.
///
/// It does not use `TimeDisplay`, and that is a gap rather than a decision:
/// `TimeDisplay.secondary` takes a `LocalizedStringResource`, and this line is
/// not catalog text — `LoopTimeFormat.weekdayAndDate` builds it from the
/// region's own order of weekday, day and month. The two are the same layout
/// and should be the same view once `TimeDisplay` can take a verbatim secondary.
private struct ClockTimeBlock: View {

    let face: ClockFace

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopInk) private var ink

    var body: some View {
        VStack(spacing: metrics.timeBlockSpacing) {
            // The size follows the length of the string, not the width of the
            // container: "09:41:07" is eight characters and draws at 65 pt,
            // "09:41" is five and draws full size. `LoopTypography` owns the
            // rule, including the smaller landscape base.
            Text(verbatim: face.time)
                .loopTextStyle(typography.bigTime(characterCount: face.time.count))
                .monospacedDigit()

            Text(verbatim: face.dateLine)
                .loopTextStyle(typography.secondaryLine)
        }
        .foregroundStyle(ink.base)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Optical centring against the page, not against the space this block
        // happens to get. An offset rather than a padding, so the block claims
        // the same height either way.
        .offset(y: metrics.timeBlockOffset)
    }
}

// MARK: - Schedule

/// A `TimelineSchedule` that fires on whole-period boundaries of the wall
/// clock — every second, or every minute.
///
/// `TimelineSchedule.periodic` counts from the date it is handed, and the date
/// to hand it is `.now` at the point of construction — there is nothing else to
/// pass. So its boundaries fall wherever the view happened to be built, and a
/// minute cadence would flip the displayed minute at that offset and read wrong
/// for up to fifty-nine seconds. Aligning to the wall clock rather than to the
/// view's own history is the whole reason this type exists.
private struct WallClockSchedule: TimelineSchedule {

    // MARK: - Cadences

    // The two cadences the clock has, and the only numeric literals in this
    // file. A tick cadence is not a design value — it is not in the export
    // because a still image cannot contain one — so it is named here, once, and
    // every use reads one of these two names. `minute` is both the cadence for
    // a page without seconds and the floor the low-frequency clamp drops to;
    // writing that 60 a second time would let the two drift apart.

    /// One tick a second, for a page that is showing seconds.
    static let second: TimeInterval = 1

    /// One tick a minute — the coarsest this page ever runs at, and still
    /// enough to show the right time.
    static let minute: TimeInterval = 60

    // MARK: - Schedule

    /// The gap between boundaries, in seconds.
    let period: TimeInterval

    func entries(from startDate: Date, mode: Mode) -> AnyIterator<Date> {
        // `.lowFrequency` is the system asking for fewer updates — a dimmed
        // always-on screen, where a second hand is neither readable nor worth
        // the wake.
        let period = mode == .lowFrequency ? max(self.period, Self.minute) : self.period

        // The first entry is the moment asked for, so the page draws
        // immediately rather than waiting out the first boundary.
        var pending: Date? = startDate
        var next = Self.boundary(after: startDate, period: period)

        return AnyIterator {
            if let first = pending {
                pending = nil
                return first
            }
            defer { next = next.addingTimeInterval(period) }
            return next
        }
    }

    /// The first boundary strictly after `date`.
    ///
    /// Measured against the reference date — 2001-01-01 00:00:00 UTC — so a
    /// whole number of seconds and a whole number of minutes both land where
    /// the wall clock changes, in every time zone the device can be set to. A
    /// zone offset is always a whole number of minutes, including the half and
    /// three-quarter hour ones, so a minute boundary in UTC is a minute
    /// boundary everywhere.
    private static func boundary(after date: Date, period: TimeInterval) -> Date {
        let elapsed = date.timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (elapsed / period).rounded(.down) * period + period)
    }
}

// MARK: - Preview

#Preview {
    ClockScreen()
        .environment(LoopSettings(defaults: UserDefaults(suiteName: "preview") ?? .standard))
}
