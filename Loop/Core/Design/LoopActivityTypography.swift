import SwiftUI

// MARK: - Type scale

/// The two type sizes a Live Activity needs and the app does not have.
///
/// Loop's big time is 104 pt. A lock-screen activity is roughly a sixth of that
/// height and the Dynamic Island's compact region is a strip beside the camera,
/// so neither can borrow it. The roles below are the same font, weight and
/// tracking as `LoopTypography.bigTime` — the identity of the number is the
/// light weight and the tight tracking, not the size — at the two sizes this
/// surface has room for.
///
/// They sit beside the rest of the scale rather than in the extension: the
/// target that draws a value is not what decides where it is written down.
enum LoopActivityTypography {

    /// The tracking of the big time, which is what makes the digits read as
    /// Loop's rather than as any monospaced font's.
    private static let timeTrackingEm: CGFloat = -0.055

    /// The time on the lock screen and in the expanded Dynamic Island.
    static let time = LoopTextStyle(weight: .light, size: 34, trackingEm: timeTrackingEm)

    /// How far the time may shrink to fit its own length.
    ///
    /// A countdown runs to thirty hours, so the digits are anywhere from five
    /// characters ("25:00") to eight ("30:00:00"). The app's big time solves
    /// this by scaling with the character count; a Live Activity card has one
    /// width the system chose, so the shrink is left to the text itself. The
    /// floor is the ratio of five characters to eight — the longest string the
    /// engine can produce, at the size the shortest one is drawn.
    static let timeMinimumScale: CGFloat = 5.0 / 8.0

    /// The time in the compact Dynamic Island, where the strip beside the
    /// camera is all the room there is.
    static let compactTime = LoopTextStyle(weight: .regular, size: 14, trackingEm: timeTrackingEm)

    /// The room the compact time is given, for a string of `characters`.
    ///
    /// **This is what keeps the island the size of an island.** A compact slot
    /// sizes to its content, and `Text(timerInterval:)` has no content to size
    /// to — iOS renders the digits itself, so SwiftUI is measuring a text it
    /// cannot see and asks for far more width than the digits use. The result
    /// was the whole reason this function exists: a black pill across most of
    /// the status bar with `4:48` adrift in the middle of it.
    ///
    /// Reserved rather than measured, because there is nothing to measure. The
    /// count comes from
    /// `LoopActivityAttributes.ContentState.timeCharacters`, and the width is
    /// the font's own advance times the size — no tracking subtracted, so the
    /// negative tracking of the role leaves a hair of slack rather than
    /// clipping the last digit.
    static func compactTimeWidth(characters: Int) -> CGFloat {
        CGFloat(characters) * compactTime.size * LoopFonts.advanceEm
    }
}
