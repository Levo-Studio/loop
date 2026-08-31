import Foundation

// MARK: - Clock face

/// What the clock page draws: a time and the line under it.
///
/// There is no state to keep — the page is a function of the instant it is
/// drawn at — so this is a value built per tick rather than a timer.
nonisolated struct ClockFace: Sendable, Equatable {

    /// `09:41` or `09:41:07`, depending on the setting.
    let time: String

    /// The weekday and date under the time.
    let date: String

    init(
        date: Date,
        showSeconds: Bool,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        time = LoopTimeFormat.wallClock(date, showSeconds: showSeconds, calendar: calendar)
        self.date = LoopTimeFormat.weekdayAndDate(date, locale: locale, timeZone: timeZone)
    }
}
