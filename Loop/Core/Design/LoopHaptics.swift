import UIKit

// MARK: - Haptics

/// The one tap of feedback the app gives, fired from the gesture that caused
/// it.
///
/// Deliberately imperative rather than `.sensoryFeedback`, which watches a
/// value and fires wherever it is attached. Every control that can be dragged
/// or tapped lives inside `FillSurface`'s content, and that content is built
/// twice — so a value-watching modifier is installed twice and fires twice for
/// one detent. Firing from the handler ties the feedback to the interaction
/// instead, and only one of the two layers takes interactions.
enum LoopHaptics {

    /// Prepared once and reused. A generator created per detent arrives late
    /// on the first one, which on a slider is every drag.
    private static let selection = UISelectionFeedbackGenerator()

    /// A single detent: one minute on a scale, one round on a stepper.
    static func detent() {
        selection.selectionChanged()
        // Keeps the Taptic Engine warm for the next detent of the same drag.
        selection.prepare()
    }
}
