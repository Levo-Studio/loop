import SwiftUI

// MARK: - Metrics

/// The spacings the Live Activity needs and the app does not have.
///
/// A lock-screen activity is laid out by the system inside its own card, so the
/// app's page padding — which is measured against a full screen — is the wrong
/// number rather than a number that needs scaling. These are the two it needs
/// instead, and they live here with the rest of the design layer because that is
/// where a value with a number in it belongs, whichever target draws it.
enum LoopActivityMetrics {

    /// Inset of the lock-screen card's content from the card's own edges.
    static let cardPadding: CGFloat = 16

    /// Gap between the pill and the time.
    static let stackSpacing: CGFloat = 8

    // MARK: - The accent mark

    /// The accent dot in the compact Dynamic Island.
    ///
    /// The pill draws a 6 pt dot beside an 11 pt label, and it is that
    /// proportion — not the 6 pt — that makes it read as a mark rather than a
    /// bullet. The compact slot sets the time at its own size, so the dot
    /// follows that size by the same ratio instead of carrying the pill's
    /// absolute value onto a surface the export never drew. Taken from the
    /// role rather than restated, so the dot stays proportional to a time
    /// whose size is changed.
    static let compactMarkSize: CGFloat = LoopActivityTypography.compactTime.size * markRatio

    /// The accent dot in the minimal Dynamic Island.
    ///
    /// The minimal presentation is a circle of roughly 22 pt that Loop shares
    /// with another app's, and it has no text for the dot to be proportional
    /// to. Half the circle is the size that reads as a mark inside it: smaller
    /// is a speck at a glance, and larger fills the region into a solid disc
    /// that looks like the region itself rather than like something Loop drew.
    static let minimalMarkSize: CGFloat = 11

    /// `LoopMetrics.pillDotSize` over `LoopTypography.statusPill`'s size, both
    /// at the phone's scale — the one place the two are related.
    ///
    /// Read from the two roles rather than written as `6.0 / 11.0`: a ratio
    /// copied out of its sources is a ratio that goes quietly wrong the day one
    /// of them moves. The phone's scale is the right reading of both because
    /// the ratio is what is wanted here, and `scale` cancels out of it — the
    /// Dynamic Island has no idiom of its own to ask for.
    private static let markRatio: CGFloat =
        LoopMetrics(isPad: false, isLandscape: false).pillDotSize
        / LoopTypography(scale: 1, isLandscape: false).statusPill.size
}
