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

    static let running = LocalizedStringResource(
        "state.running",
        defaultValue: "running",
        comment: "Status pill detail while the stopwatch is counting"
    )

    /// The dimmed half of the pill on a held count-up or countdown, where the
    /// pill's own label is the page name.
    ///
    /// The export uses two different words for being held — `pausiert` in the
    /// pill and `angehalten` under the time — and English has to keep them
    /// apart too, or the same word is drawn twice on one screen. The pill says
    /// which state the timer is in; `onHold` says what has happened to the
    /// time. The names carry their slot so the two cannot be swapped by
    /// reaching for the obvious one.
    static let pausedDetail = LocalizedStringResource(
        "state.pausedDetail",
        defaultValue: "paused",
        comment: "Status pill detail on a held count-up or countdown, beside the page name"
    )

    /// The pill's label on a held interval, which moves the block and the round
    /// into the detail beside it.
    static let pausedStatus = LocalizedStringResource(
        "state.pausedStatus",
        defaultValue: "Paused",
        comment: "Status pill label while an interval is held"
    )

    /// The line under the time on any held timer. See `pausedDetail` for why
    /// this is a second word rather than the same one.
    static let onHold = LocalizedStringResource(
        "state.onHold",
        defaultValue: "on hold",
        comment: "Line under the time while a timer is held, on all three timer pages"
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

    // MARK: - Lines under the time

    /// "since 09:29" — the stopwatch's running line, naming the instant the run
    /// began.
    static func since(_ time: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "line.since",
            defaultValue: "since \(time)",
            comment: "Line under the stopwatch naming the wall-clock time a run started"
        )
    }

    /// "of 25:00" — the running line of the countdown and of the interval,
    /// naming the length of the block being counted.
    static func ofDuration(_ duration: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "line.of",
            defaultValue: "of \(duration)",
            comment: "Line under a counting timer naming the full length of the current block"
        )
    }

    /// "25:00 completed" — the countdown's finished line. The number sits
    /// inside the sentence here, unlike the interval's finished line, where the
    /// export draws it as the large time above.
    static func completed(_ duration: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "line.completed",
            defaultValue: "\(duration) completed",
            comment: "Line under a finished countdown naming the duration that was run"
        )
    }

    /// The interval's finished line, under a large "2:00".
    ///
    /// The number is drawn above rather than inside the line, so the plural has
    /// to be chosen from the value rather than left to the catalog. Only a
    /// total of exactly one hour reads "hour"; 1:30 and 0:00 both take the
    /// plural, as English wants.
    static func hoursFocused(_ duration: TimeInterval) -> LocalizedStringResource {
        duration == 3_600 ? hourFocused : manyHoursFocused
    }

    private static let hourFocused = LocalizedStringResource(
        "line.hourFocused",
        defaultValue: "hour focused",
        comment: "Line under a finished interval when the total is exactly one hour"
    )

    private static let manyHoursFocused = LocalizedStringResource(
        "line.hoursFocused",
        defaultValue: "hours focused",
        comment: "Line under a finished interval, under the total drawn as the large time"
    )

    // MARK: - Status pill

    /// "Round 02 / 04" — the dimmed half of the pill while an interval runs.
    ///
    /// The counter is padded to two digits, as the export draws it, and the
    /// padding is done here rather than in the catalog: digits are not
    /// translatable, and four screens each padding their own would eventually
    /// disagree.
    static func roundCounter(current: Int, total: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "pill.round",
            defaultValue: "Round \(paddedCounter(current: current, total: total))",
            comment: "Status pill detail naming the round an interval is in, as \"Round 02 / 04\""
        )
    }

    /// "Focus · 02 / 04" — the dimmed half of the pill while an interval is
    /// held, where the pill's own label is "Paused" and the block has to move
    /// into the detail.
    static func blockAndRound(_ block: LocalizedStringResource, current: Int, total: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "pill.blockAndRound",
            defaultValue: "\(String(localized: block)) · \(paddedCounter(current: current, total: total))",
            comment: "Status pill detail while an interval is held, as \"Focus · 02 / 04\""
        )
    }

    /// "Done · 4 of 4" — the whole pill on a finished interval, which the
    /// export draws as one run rather than as a label and a detail. The rounds
    /// are not padded here; the export writes them plain.
    static func doneRounds(_ rounds: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "pill.doneRounds",
            defaultValue: "Done · \(rounds) of \(rounds)",
            comment: "Whole status pill of a finished interval, as \"Done · 4 of 4\""
        )
    }

    /// Digits and a slash, so no catalog entry.
    private static func paddedCounter(current: Int, total: Int) -> String {
        String(format: "%02d / %02d", current, total)
    }

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

    /// The instruction read through the slide-to-stop track on a ringing
    /// countdown.
    ///
    /// "Stop" rather than "dismiss", because the app already has a Stop button
    /// and this is the same act on a state that is making a noise: the words on
    /// the controls of this app say what the control does, not what happens to
    /// the screen afterwards. The direction is not named — the knob is drawn
    /// at the left end of the track and there is only one way for it to go, so
    /// a promise of "right" would repeat what the drawing has already said.
    static let slideToStop = LocalizedStringResource(
        "control.slideToStop",
        defaultValue: "Slide to stop",
        comment: "Instruction inside the track that dismisses a ringing countdown"
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

    /// "Total 2:00 h" — the line under the interval's stepper. One run in the
    /// export, so one key: a screen joining a label, a number and a unit would
    /// be three fragments no translator can reorder.
    static func total(_ value: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "setup.total",
            defaultValue: "Total \(value) h",
            comment: "Sum of an interval's blocks under the round stepper, as \"Total 2:00 h\""
        )
    }

    static let minutesUnit = LocalizedStringResource(
        "unit.minutes",
        defaultValue: " min",
        comment: "Unit after a duration value; the leading space separates it from the number"
    )

    /// The unit after a duration written as `h:mm`, so a scale reading past an
    /// hour says "2:05 h" rather than "125 min".
    ///
    /// The same " h" the interval's total carries. It is a second key rather
    /// than a fragment lifted out of `total(_:)`: that line is one run in the
    /// export and stays one key, because a translator has to be able to reorder
    /// the label, the number and the unit inside it.
    static let hoursUnit = LocalizedStringResource(
        "unit.hours",
        defaultValue: " h",
        comment: "Unit after a duration value written as h:mm; the leading space separates it from the number"
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

    /// "Sound" — the label of the toggle that governs all three tones. One
    /// switch, so one word: naming a single cue here would promise a choice
    /// the setting does not offer.
    static let sound = LocalizedStringResource(
        "settings.sound",
        defaultValue: "Sound",
        comment: "Label of the toggle that turns the app's three tones on and off"
    )

    /// "Swipe to dismiss the countdown" — the label of the toggle behind
    /// `LoopDismissal`. The countdown is named in the label because the
    /// interval deliberately ignores this setting, and a bare "Swipe to
    /// dismiss" would read as applying to both.
    static let swipeToDismiss = LocalizedStringResource(
        "settings.swipeToDismiss",
        defaultValue: "Swipe to dismiss the countdown",
        comment: "Label of the toggle that makes a finished countdown wait for a swipe, like an alarm"
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
