import Foundation

// MARK: - Strings

/// Every visible word in the app, in one place.
///
/// Views hold no literals: a string in a view is a string that never reaches the
/// catalog, and the first person to look for it looks in the wrong file. The
/// keys below are the catalog's keys, and the default values are the English the
/// app ships with — the catalog is maintained by hand, so both sides have to be
/// written out here.
nonisolated enum LoopStrings {

    // MARK: - Pages

    static let clock = LocalizedStringResource(
        "page.clock",
        defaultValue: "Clock",
        comment: "Status pill and page name of the clock page"
    )

    static let countUp = LocalizedStringResource(
        "page.countUp",
        defaultValue: "Count-up",
        comment: "Status pill and page name of the stopwatch page"
    )

    static let countdown = LocalizedStringResource(
        "page.countdown",
        defaultValue: "Countdown",
        comment: "Status pill and page name of the countdown page"
    )

    static let interval = LocalizedStringResource(
        "page.interval",
        defaultValue: "Interval",
        comment: "Status pill and page name of the interval page"
    )

    static let settings = LocalizedStringResource(
        "page.settings",
        defaultValue: "Settings",
        comment: "Heading of the settings page"
    )

    // MARK: - States

    static let ready = LocalizedStringResource(
        "state.ready",
        defaultValue: "ready",
        comment: "Line under the time before a timer has been started"
    )

    static let paused = LocalizedStringResource(
        "state.paused",
        defaultValue: "paused",
        comment: "Line under the time while a timer is held"
    )

    static let pausedStatus = LocalizedStringResource(
        "state.pausedStatus",
        defaultValue: "Paused",
        comment: "Status pill label while a timer is held"
    )

    static let done = LocalizedStringResource(
        "state.done",
        defaultValue: "Done",
        comment: "Status pill label once a run has finished"
    )

    static let focus = LocalizedStringResource(
        "block.focus",
        defaultValue: "Focus",
        comment: "The working block of an interval"
    )

    static let breakBlock = LocalizedStringResource(
        "block.break",
        defaultValue: "Break",
        comment: "The resting block of an interval"
    )

    // MARK: - Controls

    static let start = LocalizedStringResource(
        "control.start",
        defaultValue: "Start",
        comment: "Button that begins a timer"
    )

    static let pause = LocalizedStringResource(
        "control.pause",
        defaultValue: "Pause",
        comment: "Button that holds a running timer"
    )

    static let resume = LocalizedStringResource(
        "control.resume",
        defaultValue: "Resume",
        comment: "Button that continues a held timer"
    )

    static let reset = LocalizedStringResource(
        "control.reset",
        defaultValue: "Reset",
        comment: "Button that returns a page to its setup state"
    )

    static let stop = LocalizedStringResource(
        "control.stop",
        defaultValue: "Stop",
        comment: "Button that ends a running timer"
    )

    static let skip = LocalizedStringResource(
        "control.skip",
        defaultValue: "Skip",
        comment: "Button that jumps from a break to the next focus block"
    )

    static let restart = LocalizedStringResource(
        "control.restart",
        defaultValue: "Restart",
        comment: "Button that runs a finished timer again"
    )

    static let close = LocalizedStringResource(
        "control.close",
        defaultValue: "Close",
        comment: "Button that leaves the finished state"
    )

    // MARK: - Fields

    static let duration = LocalizedStringResource(
        "field.duration",
        defaultValue: "Duration",
        comment: "Label of the countdown's minute scale"
    )

    static let rounds = LocalizedStringResource(
        "field.rounds",
        defaultValue: "Rounds",
        comment: "Label of the interval's round stepper"
    )

    static let minutesUnit = LocalizedStringResource(
        "unit.minutes",
        defaultValue: " min",
        comment: "Unit after a duration value; the leading space separates it from the number"
    )

    static let timesUnit = LocalizedStringResource(
        "unit.times",
        defaultValue: " ×",
        comment: "Unit after a round count; the leading space separates it from the number"
    )

    // MARK: - Settings

    static let secondsInTheClock = LocalizedStringResource(
        "settings.secondsInTheClock",
        defaultValue: "Seconds in the clock",
        comment: "Label of the toggle that shows seconds on the clock page"
    )

    static let accentColour = LocalizedStringResource(
        "settings.accentColour",
        defaultValue: "Accent colour",
        comment: "Heading of the accent list"
    )

    static let activeAccent = LocalizedStringResource(
        "settings.activeAccent",
        defaultValue: "Active",
        comment: "Marker on the accent row that is currently in use"
    )

    static let footer = LocalizedStringResource(
        "settings.footer",
        defaultValue: "Loop · Levo Studio · Built in Germany",
        comment: "The line at the bottom of the settings page. Not translated."
    )

    // MARK: - Accents

    static func accentName(_ accent: LoopAccent) -> LocalizedStringResource {
        switch accent {
        case .petrol: petrol
        case .amber: amber
        case .lilac: lilac
        case .graphite: graphite
        }
    }

    private static let petrol = LocalizedStringResource(
        "accent.petrol",
        defaultValue: "Petrol",
        comment: "Name of the default accent, a muted blue-green"
    )

    private static let amber = LocalizedStringResource(
        "accent.amber",
        defaultValue: "Amber",
        comment: "Name of the warm yellow accent"
    )

    private static let lilac = LocalizedStringResource(
        "accent.lilac",
        defaultValue: "Lilac",
        comment: "Name of the muted violet accent"
    )

    private static let graphite = LocalizedStringResource(
        "accent.graphite",
        defaultValue: "Graphite",
        comment: "Name of the neutral accent"
    )
}
