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

    /// The rising area following the timer *within* one block.
    ///
    /// Linear, and never a spring: the area stands for elapsed time, and a
    /// spring would carry it past a boundary it has not reached.
    static let fill = Animation.linear(duration: tickInterval)

    /// A change the user made: a slider detent, an accent, a page.
    static let selection = Animation.easeOut(duration: 0.18)

    /// A scale coasting to rest on a detent after the finger has left it.
    ///
    /// Longer than `selection`, and it has to be: `selection` covers a change
    /// that has already happened by the time it is drawn, while this one covers
    /// a distance the flick asked for — on a scale that runs to thirty hours
    /// that can be hours of travel, and 0.18 s of it reads as a jump rather
    /// than as coasting. Eased out rather than sprung, because a scroll that
    /// overshoots its detent and comes back has picked a value the finger did
    /// not.
    static let settle = Animation.easeOut(duration: 0.45)

    /// The animation to actually use, given the accessibility setting.
    ///
    /// Central on purpose. Reduce Motion has to be honoured at every animated
    /// call site, and at a dozen call sites it would be forgotten at ten of
    /// them. `nil` means SwiftUI applies the change without animating it — the
    /// fill still tracks the timer, it simply steps instead of sliding.
    static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    /// How the rising area should move to a new fraction.
    ///
    /// Inside a block it interpolates, so the area tracks the timer. At a block
    /// boundary it **jumps**: the notes are explicit that the area snaps to
    /// zero and rises again when an interval changes block, and a one-second
    /// slide from full back down to empty is not a faster version of that — it
    /// is a different animation that reads as the timer running backwards.
    ///
    /// A pure function of the two facts it needs, so the rule can be tested
    /// without a view.
    static func fill(blockChanged: Bool, reduceMotion: Bool) -> Animation? {
        blockChanged ? nil : resolve(fill, reduceMotion: reduceMotion)
    }
}
