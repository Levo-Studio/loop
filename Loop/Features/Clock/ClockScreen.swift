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
        settings.showSeconds ? Self.secondCadence : Self.minuteCadence
    }

    private static let secondCadence: TimeInterval = 1
    private static let minuteCadence: TimeInterval = 60
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
/// `TimelineSchedule.periodic` counts from the moment the view appeared, so a
/// minute cadence would flip the displayed minute at whatever offset the view
/// happened to be created at and would read wrong for up to fifty-nine seconds.
/// Aligning to the boundary is the whole reason this type exists.
private struct WallClockSchedule: TimelineSchedule {

    /// The gap between boundaries, in seconds.
    let period: TimeInterval

    func entries(from startDate: Date, mode: Mode) -> AnyIterator<Date> {
        // `.lowFrequency` is the system asking for fewer updates — a dimmed
        // always-on screen, where a second hand is neither readable nor worth
        // the wake. It drops to the minute, which is the coarsest cadence this
        // page has and still shows the right time.
        let period = mode == .lowFrequency ? max(self.period, Self.lowFrequencyPeriod) : self.period

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
    /// Measured against the reference date, which is midnight UTC — so a whole
    /// number of seconds and a whole number of minutes both land where the wall
    /// clock changes, in every time zone the device can be set to.
    private static func boundary(after date: Date, period: TimeInterval) -> Date {
        let elapsed = date.timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (elapsed / period).rounded(.down) * period + period)
    }

    /// The slowest the clock is allowed to run, in seconds.
    private static let lowFrequencyPeriod: TimeInterval = 60
}

// MARK: - Preview

#Preview {
    ClockScreen()
        .environment(LoopSettings(defaults: UserDefaults(suiteName: "preview") ?? .standard))
}
