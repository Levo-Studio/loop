import Foundation

// MARK: - Fill progress

/// How full the rising area is, and which block it is measuring.
///
/// The two travel together because they are only meaningful together. A
/// fraction on its own cannot say whether 0.98 → 0.02 is a block ending and the
/// next one starting, or a timer that somehow ran backwards — and the design
/// draws those two things completely differently. Binding them into one value
/// means a screen cannot hand over a fraction without saying what it is a
/// fraction *of*.
/// Not `Sendable`, unlike most of the design layer: `AnyHashable` is not, and
/// making it so would mean pinning the block down to one concrete type that
/// every screen has to bend its own state into. This value is built and read
/// on the main actor inside a view body and never crosses an isolation
/// boundary, so the conformance would buy nothing.
nonisolated struct FillProgress: Equatable {

    /// 0…1 over the duration of the current block. Clamped on the way in: a
    /// screen mid-transition should not be able to ask for an area taller than
    /// the page, and clamping here means no call site has to remember to.
    let fraction: Double

    /// Identifies the block the fraction belongs to.
    ///
    /// Any value that changes exactly when a new block starts and holds still
    /// while one runs. For the interval that is the phase and the round —
    /// focus 2 and break 2 are different blocks. For the countdown it is the
    /// run: a restart is a new block, the same run counting down is not.
    let block: AnyHashable

    init(fraction: Double, block: some Hashable) {
        self.fraction = min(1, max(0, fraction))
        self.block = AnyHashable(block)
    }

    /// No area at all.
    ///
    /// The right value for the clock, the count-up, and every setup, idle and
    /// stopped state. The area is a progress indicator: with no block duration
    /// to measure against there is no progress, so there is nothing to draw —
    /// not a sliver, not a resting height, not a tint.
    /// Computed rather than stored: a `static let` of a non-`Sendable` type is
    /// shared mutable state as far as the compiler is concerned, and building
    /// two empty structs costs nothing.
    static var none: FillProgress { FillProgress(fraction: 0, block: NoBlock()) }

    /// The block identity of `none`. A private type, so nothing else can
    /// accidentally share an identity with "no area".
    private struct NoBlock: Hashable {}
}
