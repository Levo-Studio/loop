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

// MARK: - One tap per detent

/// Remembers which detent the last tap was for, so that a drag taps once per
/// detent it lands on rather than once per gesture callback.
///
/// A drag reports far more often than the scale changes value — several
/// callbacks pass while the marker is still over the same minute — so
/// something has to say which of them is a new detent. That used to be the
/// same comparison that decided whether to write the value at all, and the two
/// questions only look alike. The value is written through a binding whose
/// getter reads the snapshot the frame was built from, so it answers one body
/// pass behind the writes; the tap has to be decided against state that is
/// current *inside* the pass, and this is that state.
///
/// Deliberately a plain value rather than a comparison buried in a gesture
/// handler: a gesture cannot be run from a test, and this rule is the half of
/// the old comparison that was actually load-bearing.
struct DetentFeedback {

    /// `nil` before a gesture has said where it starts, which is only ever the
    /// case for a freshly built one.
    private var lastTapped: Int?

    /// Takes the detent a gesture starts from, so that putting a finger down
    /// and not moving it is silent.
    mutating func begin(at detent: Int) {
        lastTapped = detent
    }

    /// Whether arriving at `detent` is arriving somewhere new, and therefore
    /// owed a tap.
    ///
    /// Asking also records the answer: the same detent reported again by the
    /// next callback is the same detent, not a second choice.
    mutating func arrived(at detent: Int) -> Bool {
        guard detent != lastTapped else { return false }
        lastTapped = detent
        return true
    }
}
