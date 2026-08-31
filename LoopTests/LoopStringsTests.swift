import Foundation
import Testing

@testable import Loop

// MARK: - Strings

/// The catalog is maintained by hand, so the words a view draws and the words
/// written next to the key are two separate things that have to agree.
///
/// These resolve through the catalog rather than reading `defaultValue`, which
/// is the whole point: a resource falls back to its default when the catalog
/// has no entry, so a test that read the default would pass against an empty
/// catalog, a missing key, or a value mangled on its way in.
@Suite("Strings")
struct LoopStringsTests {

    private func resolved(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }

    @Test("The non-ASCII strings survive the catalog")
    func nonASCIIStrings() {
        // Both of these have been wrong once. The unit is a multiplication
        // sign and the footer is separated by middle dots; either one written
        // through the wrong encoding shows up in the app as mojibake and
        // nowhere else.
        #expect(resolved(LoopStrings.timesUnit) == " \u{00D7}")
        #expect(resolved(LoopStrings.footer) == "Loop \u{00B7} Levo Studio \u{00B7} Built in Germany")
    }

    @Test("Every string resolves to the words it declares")
    func everyStringResolves() {
        let expected: [(LocalizedStringResource, String)] = [
            (LoopStrings.clock, "Clock"),
            (LoopStrings.countUp, "Count-up"),
            (LoopStrings.countdown, "Countdown"),
            (LoopStrings.interval, "Interval"),
            (LoopStrings.settings, "Settings"),
            (LoopStrings.ready, "ready"),
            (LoopStrings.pausedDetail, "paused"),
            (LoopStrings.onHold, "on hold"),
            (LoopStrings.running, "running"),
            (LoopStrings.pausedStatus, "Paused"),
            (LoopStrings.done, "Done"),
            (LoopStrings.focus, "Focus"),
            (LoopStrings.breakBlock, "Break"),
            (LoopStrings.start, "Start"),
            (LoopStrings.pause, "Pause"),
            (LoopStrings.resume, "Resume"),
            (LoopStrings.reset, "Reset"),
            (LoopStrings.stop, "Stop"),
            (LoopStrings.skip, "Skip"),
            (LoopStrings.restart, "Restart"),
            (LoopStrings.close, "Close"),
            (LoopStrings.duration, "Duration"),
            (LoopStrings.rounds, "Rounds"),
            (LoopStrings.minutesUnit, " min"),
            (LoopStrings.secondsInTheClock, "Seconds in the clock"),
            (LoopStrings.accentColour, "Accent colour"),
            (LoopStrings.activeAccent, "Active"),
        ]

        for (resource, words) in expected {
            #expect(resolved(resource) == words)
        }
    }

    @Test("The composed lines resolve through the catalog with their numbers in place")
    func composedLines() {
        // Each of these is one text run in the export, which is why it is one
        // key: a screen gluing a label to a number and a unit would be
        // fragments no translator can reorder.
        #expect(resolved(LoopStrings.since("09:29")) == "since 09:29")
        #expect(resolved(LoopStrings.ofDuration("25:00")) == "of 25:00")
        #expect(resolved(LoopStrings.completed("25:00")) == "25:00 completed")
        #expect(resolved(LoopStrings.total("2:00")) == "Total 2:00 h")
    }

    @Test("The finished interval line takes the plural from the total")
    func hoursFocused() {
        // The number is the large time above the line, not part of it, so
        // nothing in the catalog can pick the plural — the value has to.
        #expect(resolved(LoopStrings.hoursFocused(3_600)) == "hour focused")
        #expect(resolved(LoopStrings.hoursFocused(2 * 3_600)) == "hours focused")
        #expect(resolved(LoopStrings.hoursFocused(5_400)) == "hours focused")
        #expect(resolved(LoopStrings.hoursFocused(0)) == "hours focused")
    }

    @Test("The round counter is padded to two digits, as the export draws it")
    func roundCounter() {
        #expect(resolved(LoopStrings.roundCounter(current: 2, total: 4)) == "Round 02 / 04")
        #expect(resolved(LoopStrings.roundCounter(current: 12, total: 99)) == "Round 12 / 99")

        // The held pill moves the block into the detail, still padded.
        #expect(resolved(LoopStrings.blockAndRound(LoopStrings.focus, current: 2, total: 4))
            == "Focus \u{00B7} 02 / 04")
        #expect(resolved(LoopStrings.blockAndRound(LoopStrings.breakBlock, current: 1, total: 3))
            == "Break \u{00B7} 01 / 03")

        // The finished pill is one run and writes its rounds plain.
        #expect(resolved(LoopStrings.doneRounds(4)) == "Done \u{00B7} 4 of 4")
    }

    @Test("Every key a screen can draw is actually in the catalog")
    func everyKeyIsInTheCatalog() {
        // Resolving is not enough on its own: a resource whose key is missing
        // from the catalog falls back to the `defaultValue` written beside it,
        // so a comparison against the expected words passes against a catalog
        // that never got the entry. Asking the bundle for the key with a
        // sentinel default is the only way to see the hole.
        let sentinel = "\u{0000}missing"

        let resources: [LocalizedStringResource] = [
            LoopStrings.clock, LoopStrings.countUp, LoopStrings.countdown,
            LoopStrings.interval, LoopStrings.settings,
            LoopStrings.ready, LoopStrings.running, LoopStrings.pausedDetail,
            LoopStrings.onHold,
            LoopStrings.pausedStatus, LoopStrings.done,
            LoopStrings.focus, LoopStrings.breakBlock,
            LoopStrings.start, LoopStrings.pause, LoopStrings.resume,
            LoopStrings.reset, LoopStrings.stop, LoopStrings.skip,
            LoopStrings.restart, LoopStrings.close,
            LoopStrings.duration, LoopStrings.rounds,
            LoopStrings.minutesUnit, LoopStrings.timesUnit,
            LoopStrings.secondsInTheClock, LoopStrings.accentColour,
            LoopStrings.activeAccent, LoopStrings.footer,
            LoopStrings.since("09:29"), LoopStrings.ofDuration("25:00"),
            LoopStrings.completed("25:00"), LoopStrings.total("2:00"),
            LoopStrings.hoursFocused(3_600), LoopStrings.hoursFocused(7_200),
            LoopStrings.roundCounter(current: 2, total: 4),
            LoopStrings.blockAndRound(LoopStrings.focus, current: 2, total: 4),
            LoopStrings.doneRounds(4),
        ] + LoopAccent.allCases.map(LoopStrings.accentName)

        for resource in resources {
            let key = String(describing: resource.key)
            let value = Bundle.main.localizedString(forKey: key, value: sentinel, table: nil)
            #expect(value != sentinel, "\(key) is declared in LoopStrings but missing from the catalog")
        }
    }

    @Test("Every accent is named, in English")
    func accentNames() {
        // The export names them in German; only the words change.
        let expected: [LoopAccent: String] = [
            .petrol: "Petrol",
            .amber: "Amber",
            .lilac: "Lilac",
            .graphite: "Graphite",
        ]

        for accent in LoopAccent.allCases {
            #expect(resolved(LoopStrings.accentName(accent)) == expected[accent])
        }
    }
}
