import SwiftUI

// MARK: - Metrics

/// The spacings the Live Activity needs and the app does not have.
///
/// Same reasoning as `LoopActivityTypography`: these are design values, they
/// belong beside the ones they are derived from, and they sit here only because
/// nothing outside the extension draws this surface. A lock-screen activity is
/// laid out by the system inside its own card, so the app's page padding — which
/// is measured against a full screen — is the wrong number rather than a number
/// that needs scaling.
enum LoopActivityMetrics {

    /// Inset of the lock-screen card's content from the card's own edges.
    static let cardPadding: CGFloat = 16

    /// Gap between the pill and the time.
    static let stackSpacing: CGFloat = 8

    /// Height of the progress track. The system's linear progress view draws
    /// thinner than this on its own; the frame is what makes the accent read as
    /// an area rather than as a hairline.
    static let progressHeight: CGFloat = 6

    /// Gap between the dot and the time in the compact Dynamic Island.
    static let compactSpacing: CGFloat = 4
}
