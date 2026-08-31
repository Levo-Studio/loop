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
            (LoopStrings.paused, "paused"),
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
