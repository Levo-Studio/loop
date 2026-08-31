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
/// It lives in the extension rather than in `Loop/Core/Design/` only because
/// the Live Activity is the only thing that draws it. A second surface needing
/// these sizes is the moment they move next to the rest of the scale.
enum LoopActivityTypography {

    /// The tracking of the big time, which is what makes the digits read as
    /// Loop's rather than as any monospaced font's.
    private static let timeTrackingEm: CGFloat = -0.055

    /// The time on the lock screen and in the expanded Dynamic Island.
    static let time = LoopTextStyle(weight: .light, size: 34, trackingEm: timeTrackingEm)

    /// The time in the compact and minimal Dynamic Island, where the strip
    /// beside the camera is all the room there is.
    static let compactTime = LoopTextStyle(weight: .regular, size: 14, trackingEm: timeTrackingEm)
}
