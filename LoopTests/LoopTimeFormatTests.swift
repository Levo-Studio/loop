import Testing
import Foundation

@testable import Loop

// MARK: - Time format

@Suite("Time format")
struct LoopTimeFormatTests {

    @Test("Minutes and seconds are both padded")
    func minutesAndSeconds() {
        #expect(LoopTimeFormat.clock(seconds: 0) == "00:00")
        #expect(LoopTimeFormat.clock(seconds: 1_500) == "25:00")
        #expect(LoopTimeFormat.clock(seconds: 138) == "02:18")
        #expect(LoopTimeFormat.clock(seconds: 3_599) == "59:59")
    }

    @Test("From an hour on the value is eight characters")
    func hours() {
        let value = LoopTimeFormat.clock(seconds: 9 * 3_600 + 41 * 60 + 7)
        #expect(value == "09:41:07")

        // Eight characters is what the type scale shrinks the time for.
        #expect(value.count == 8)
        #expect(LoopTimeFormat.clock(seconds: 3_600) == "01:00:00")
    }

    @Test("A negative value reads as zero rather than as a minus sign")
    func negative() {
        #expect(LoopTimeFormat.clock(seconds: -30) == "00:00")
        #expect(LoopTimeFormat.remaining(-30) == "00:00")
        #expect(LoopTimeFormat.elapsed(-30) == "00:00")
    }

    @Test("A remaining value rounds up, so a fresh countdown reads 25:00")
    func remainingRoundsUp() {
        #expect(LoopTimeFormat.remaining(1_499.99) == "25:00")
        #expect(LoopTimeFormat.remaining(1_499.5) == "25:00")
        #expect(LoopTimeFormat.remaining(1_498.5) == "24:59")

        // And it reaches 00:00 exactly when the timer is over, not a second
        // early.
        #expect(LoopTimeFormat.remaining(0.4) == "00:01")
        #expect(LoopTimeFormat.remaining(0) == "00:00")
    }

    @Test("An elapsed value rounds down, the way a stopwatch does")
    func elapsedRoundsDown() {
        #expect(LoopTimeFormat.elapsed(0.9) == "00:00")
        #expect(LoopTimeFormat.elapsed(1.0) == "00:01")
        #expect(LoopTimeFormat.elapsed(59.99) == "00:59")
    }

    @Test("A total reads as hours and minutes with the hour unpadded")
    func hoursAndMinutes() {
        #expect(LoopTimeFormat.hoursAndMinutes(2 * 3_600) == "2:00")
        #expect(LoopTimeFormat.hoursAndMinutes(6_900) == "1:55")
        #expect(LoopTimeFormat.hoursAndMinutes(6_000) == "1:40")
        #expect(LoopTimeFormat.hoursAndMinutes(300) == "0:05")
        #expect(LoopTimeFormat.hoursAndMinutes(0) == "0:00")
    }

    @Test("A 24-hour region gets 24-hour time, with seconds only when asked for")
    func wallClockOn24Hours() {
        let date = Self.date(hour: 17, minute: 5, second: 7)

        #expect(Self.wallClock(date, showSeconds: true, locale: "en_GB") == "17:05:07")
        #expect(Self.wallClock(date, showSeconds: false, locale: "en_GB") == "17:05")
    }

    @Test("A 12-hour region gets 12-hour time rather than a forced 17:05")
    func wallClockOn12Hours() {
        // The type scale shrinks the time by min(1, 5 / characterCount), which
        // takes the longer string as readily as the shorter one, so there is no
        // reason to override what the device is set to.
        let afternoon = Self.date(hour: 17, minute: 5, second: 7)
        #expect(Self.wallClock(afternoon, showSeconds: true, locale: "en_US") == "5:05:07 PM")

        let morning = Self.date(hour: 9, minute: 41, second: 0)
        #expect(Self.wallClock(morning, showSeconds: false, locale: "en_US") == "9:41 AM")
    }

    @Test("The clock face carries the time and the line under it")
    func clockFace() {
        let face = ClockFace(
            date: Self.date(hour: 9, minute: 41, second: 7),
            showSeconds: true,
            locale: Locale(identifier: "en_GB"),
            timeZone: Self.timeZone
        )

        #expect(face.time == "09:41:07")
        #expect(face.dateLine == "Wednesday 12 March")
    }

    /// The system puts a narrow no-break space before AM/PM, which is correct
    /// and invisible in a comparison — normalised here so a failure reads as a
    /// failure rather than as two identical strings that are not equal.
    private static func wallClock(_ date: Date, showSeconds: Bool, locale: String) -> String {
        let value = LoopTimeFormat.wallClock(
            date,
            showSeconds: showSeconds,
            locale: Locale(identifier: locale),
            timeZone: timeZone
        )
        return value
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    // MARK: - Fixtures

    /// A fixed zone, so the same instant reads the same on every machine.
    private static let timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// 12 March 2025, a Wednesday — the date the export's clock page shows.
    private static func date(hour: Int, minute: Int, second: Int) -> Date {
        let components = DateComponents(
            year: 2025,
            month: 3,
            day: 12,
            hour: hour,
            minute: minute,
            second: second
        )
        return calendar.date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
    }
}
