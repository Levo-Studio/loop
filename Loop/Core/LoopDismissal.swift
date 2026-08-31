import Foundation

// MARK: - Dismissal

/// Whether a finished timer waits for a swipe before it lets go.
///
/// This is one rule over two screens, so it is one function rather than an
/// `if` in each of them. Countdown and Interval both draw a finished state and
/// both read the same setting; written twice, the day the setting grows a third
/// case one of the two copies keeps the old answer and nobody notices, because
/// the two screens are never on screen together.
///
/// The rule the owner set, and the reason it is asymmetric:
///
/// - **The countdown may require a swipe.** It is the alarm case — a duration
///   set to run out at a particular moment, where the whole point is that it
///   does not stop demanding attention until someone acknowledges it. That is
///   `swipeToDismiss`, and it is on by default. It is literally true now: the
///   finished state rings until it is dismissed, and the dismissal is a slide
///   across a drawn track rather than a gesture on the page.
/// - **The interval never requires a swipe.** Not at a block boundary and not
///   at the end. A boundary plays its tone and the run continues on its own;
///   making someone wipe the screen to get their break, or to get back to work,
///   interrupts the session the timer exists to protect. The setting does not
///   reach it — deliberately, which is why this takes the timer as an argument
///   rather than just returning the setting.
nonisolated enum LoopDismissal {

    // MARK: - Who is asking

    /// The two screens with a finished state. Clock has no run and Count-up
    /// never finishes on its own, so neither can ask.
    enum FinishedTimer: Sendable, CaseIterable {
        case countdown
        case interval
    }

    // MARK: - The rule

    /// Whether the finished state has to be swiped away rather than tapped or
    /// left alone.
    ///
    /// The rule kept its shape when the gesture became a control. What changed
    /// is what the screen does with the answer — it draws `SlideToStop` in the
    /// control row's place instead of arming a drag on the whole page — and
    /// that is the caller's business, not this rule's. The name stays "swipe"
    /// because the setting it reads is `swipeToDismiss`, whose stored key and
    /// visible label both say so; a rule reading one word and its input another
    /// is how the two stop matching.
    static func requiresSwipe(_ timer: FinishedTimer, swipeToDismissEnabled: Bool) -> Bool {
        switch timer {
        case .countdown: swipeToDismissEnabled
        case .interval: false
        }
    }
}
