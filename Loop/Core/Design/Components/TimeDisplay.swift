import SwiftUI

// MARK: - Time display

/// The big time and the line under it, centred in the space it is given.
///
/// The type shrinks with the length of the string rather than with the width of
/// the container: five characters ("25:00") is the reference, and "09:41:07"
/// comes out at 65 pt on iPhone because the rule is `× 5 / 8`. Measuring the
/// container instead would give a different size on every device and would make
/// the clock and the countdown disagree on the same screen.
struct TimeDisplay: View {

    /// The already formatted time. Formatting is the screen's business; this
    /// view only knows how large to set it.
    let time: String

    /// The line beneath, in whichever of the two forms the screen has.
    private let secondary: Secondary?

    // MARK: - The secondary line

    /// Where the second line's words come from.
    ///
    /// Two cases, because the screens genuinely have two. The countdown, the
    /// count-up and the interval all build theirs from a catalog phrase around
    /// a number — "of 25:00", "since 09:29", "2:00 hours focused" — and those
    /// have to go through `LocalizedStringResource` or they never reach the
    /// catalog. The clock's line has no phrase in it at all: `weekdayAndDate`
    /// asks the system for the region's own order of weekday, day and month,
    /// and there is no key that could hold that.
    ///
    /// Kept as one optional with two cases rather than two optional
    /// parameters, so there is no state where both are set and the view has to
    /// invent a rule for which wins.
    private enum Secondary {

        /// Catalog text, possibly with a formatted number in it.
        case localized(LocalizedStringResource)

        /// Text the system built at runtime, which has no catalog key.
        case verbatim(String)
    }

    // MARK: - Life cycle

    /// The usual case: a line whose words live in the string catalog.
    init(time: String, secondary: LocalizedStringResource? = nil) {
        self.time = time
        self.secondary = secondary.map(Secondary.localized)
    }

    /// A line the system formatted, with no catalog entry behind it.
    ///
    /// A separate initialiser rather than a second parameter: the two are
    /// alternatives, and a signature that accepts both invites a call passing
    /// both.
    init(time: String, secondaryText: String) {
        self.time = time
        self.secondary = .verbatim(secondaryText)
    }

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopInk) private var ink

    var body: some View {
        VStack(spacing: metrics.timeBlockSpacing) {
            Text(verbatim: time)
                .loopTextStyle(typography.bigTime(characterCount: time.count))
                .monospacedDigit()

            if let secondary {
                secondaryLine(secondary)
                    .loopTextStyle(typography.secondaryLine)
            }
        }
        .foregroundStyle(ink.base)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The block is centred against the page as a whole, not against the gap
        // it happens to sit in; the controls at the bottom pull the perceived
        // centre down, and this pulls it back. An offset rather than a padding,
        // so the space the block claims does not change with it.
        .offset(y: metrics.timeBlockOffset)
    }

    @ViewBuilder private func secondaryLine(_ secondary: Secondary) -> some View {
        switch secondary {
        case .localized(let resource): Text(resource)
        case .verbatim(let text): Text(verbatim: text)
        }
    }
}
