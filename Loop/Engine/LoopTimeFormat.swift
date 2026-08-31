import Foundation

// MARK: - Time format

/// Every number the timer screens print, formatted in one place.
///
/// Four screens showing the same shape of value is four chances to disagree
/// about padding, rounding and where the hour appears. None of the output here
/// is translatable text — it is digits and colons — so it needs no catalog
/// entry; the words around it ("of", "hours focused") belong to the screens.
nonisolated enum LoopTimeFormat {

    // MARK: - Timer values

    /// A remaining value, rounded **up**.
    ///
    /// A countdown that has just been started has a hair under its full
    /// duration left, and it has to read `25:00`, not `24:59`. Rounding up also
    /// means `00:00` appears exactly when the timer is over rather than a second
    /// early.
    static func remaining(_ interval: TimeInterval) -> String {
        clock(seconds: Int(ceil(max(0, interval) - epsilon)))
    }

    /// An elapsed value, rounded **down** — the stopwatch shows `00:00` for the
    /// first second, the way a stopwatch does.
    static func elapsed(_ interval: TimeInterval) -> String {
        clock(seconds: Int(floor(max(0, interval) + epsilon)))
    }

    /// `MM:SS` below an hour, `HH:MM:SS` from an hour on — the eight-character
    /// case the type scale shrinks for.
    static func clock(seconds: Int) -> String {
        let total = max(0, seconds)
        let hourPart = total / 3600
        let minutePart = (total % 3600) / 60
        let secondPart = total % 60

        if hourPart > 0 {
            return String(format: "%02d:%02d:%02d", hourPart, minutePart, secondPart)
        }
        return String(format: "%02d:%02d", minutePart, secondPart)
    }

    /// The total in the interval setup and on the finished screen: `2:00`, to
    /// which the screen adds its own "h" or "hours focused". Hours are not
    /// padded — the export writes `2:00 h`, not `02:00 h`.
    static func hoursAndMinutes(_ interval: TimeInterval) -> String {
        let totalMinutes = Int((max(0, interval) / 60).rounded())
        return String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
    }

    // MARK: - Wall clock

    /// The clock page's time, always 24-hour.
    ///
    /// Not the user's 12-hour setting: the whole type scale of that screen is
    /// built around a maximum of eight characters (`09:41:07`), and `9:41:07 AM`
    /// does not fit the drawing at any size the export gives.
    static func wallClock(_ date: Date, showSeconds: Bool, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0

        guard showSeconds else { return String(format: "%02d:%02d", hour, minute) }
        return String(format: "%02d:%02d:%02d", hour, minute, parts.second ?? 0)
    }

    /// Weekday and date under the clock. Built by the system rather than from a
    /// catalog string, so the order of day and month follows the region the
    /// device is set to.
    static func weekdayAndDate(
        _ date: Date,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        var style = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide)
        style.locale = locale
        style.timeZone = timeZone
        return date.formatted(style)
    }

    // MARK: - Rounding

    /// Guards against a value that is a float's hair over a whole second
    /// flipping the displayed digit.
    private static let epsilon: TimeInterval = 0.000_1
}
