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

    /// The line beneath — "of 25:00", "since 09:29", a weekday and a date.
    var secondary: LocalizedStringResource?

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopInk) private var ink

    var body: some View {
        VStack(spacing: metrics.timeBlockSpacing) {
            Text(verbatim: time)
                .loopTextStyle(typography.bigTime(characterCount: time.count))
                .monospacedDigit()

            if let secondary {
                Text(secondary)
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
}
