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
}
