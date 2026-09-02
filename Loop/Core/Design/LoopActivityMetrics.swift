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
    /// bullet. The compact slot sets the time at 14 pt, so the dot follows it
    /// by the same ratio instead of carrying the pill's absolute value onto a
    /// surface the export never drew.
    static let compactMarkSize: CGFloat = 14 * markRatio

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
    private static let markRatio: CGFloat = 6.0 / 11.0
}
