import Foundation

// MARK: - Clock face

/// What the clock page draws: a time and the line under it.
///
/// A view model rather than an engine type — it holds no state, keeps no
/// instant and decides nothing; it exists to hand one screen two ready strings.
/// The page is a function of the moment it is drawn at, so this is built per
/// tick.
nonisolated struct ClockFace: Sendable, Equatable {

    /// `09:41`, `09:41:07` or `9:41:07 AM`, following the device's setting.
    let time: String

    /// The weekday and date under the time.
    let dateLine: String

    init(
        date: Date,
        showSeconds: Bool,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        time = LoopTimeFormat.wallClock(date, showSeconds: showSeconds, locale: locale, timeZone: timeZone)
        dateLine = LoopTimeFormat.weekdayAndDate(date, locale: locale, timeZone: timeZone)
    }
}
