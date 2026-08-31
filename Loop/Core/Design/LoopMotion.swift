import SwiftUI

// MARK: - Motion

/// Every animation the app runs.
///
/// There are two, and both are deliberate. The rising fill is **linear** — it
/// stands for elapsed time, and a spring would make it overshoot a boundary it
/// has not reached yet. Everything else is a short ease for a state the user
/// caused directly.
nonisolated enum LoopMotion {

    /// How often a running timer publishes a new fraction. The fill animation
    /// lasts exactly one tick, so each step lands as the next one starts and
    /// the area appears to move continuously rather than in jumps.
    static let tickInterval: Double = 1

    /// The rising area following the timer.
    static let fill = Animation.linear(duration: tickInterval)

    /// A change the user made: a slider detent, an accent, a page.
    static let selection = Animation.easeOut(duration: 0.18)

    /// The animation to actually use, given the accessibility setting.
    ///
    /// Central on purpose. Reduce Motion has to be honoured at every animated
    /// call site, and at a dozen call sites it would be forgotten at ten of
    /// them. `nil` means SwiftUI applies the change without animating it — the
    /// fill still tracks the timer, it simply steps instead of sliding.
    static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
