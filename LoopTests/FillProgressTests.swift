import SwiftUI
import Testing

@testable import Loop

// MARK: - Fill progress

@Suite("Fill progress")
struct FillProgressTests {

    @Test("The fraction is clamped where it is built, not at the call sites")
    func fractionIsClamped() {
        #expect(FillProgress(fraction: 1.4, block: 0).fraction == 1)
        #expect(FillProgress(fraction: -0.2, block: 0).fraction == 0)
        #expect(FillProgress(fraction: 0.25, block: 0).fraction == 0.25)
    }

    @Test("No area is its own block, which nothing else can collide with")
    func noneHasAPrivateIdentity() {
        #expect(FillProgress.none.fraction == 0)

        // A screen that used 0 as its block identity must not be mistaken for
        // "no area", or the first block of a run would not count as a change.
        #expect(FillProgress.none.block != FillProgress(fraction: 0, block: 0).block)
    }

    @Test("Blocks compare across the types a screen would naturally use")
    func blockIdentity() {
        // The interval identifies a block by phase and round, the countdown by
        // its run. Both go through `AnyHashable`, so both have to compare the
        // way the screen expects.
        #expect(FillProgress(fraction: 0.5, block: [1, 0]).block == FillProgress(fraction: 0.9, block: [1, 0]).block)
        #expect(FillProgress(fraction: 0.5, block: [1, 0]).block != FillProgress(fraction: 0.5, block: [1, 1]).block)
        #expect(FillProgress(fraction: 0, block: "focus-2").block != FillProgress(fraction: 0, block: "break-2").block)
    }
}

// MARK: - The boundary rule

/// The rule the whole of item 2 comes down to, pulled out of the view so it can
/// be tested without one.
@Suite("Fill motion")
struct FillMotionTests {

    @Test("Within a block the area interpolates")
    func withinABlockItSlides() {
        #expect(LoopMotion.fill(blockChanged: false, reduceMotion: false) != nil)
    }

    @Test("At a block boundary the area jumps")
    func atABoundaryItJumps() {
        // The notes: at an interval block change the area snaps to zero and
        // rises again. A one-second slide from full back to empty is not a
        // faster version of that — it reads as the timer running backwards.
        #expect(LoopMotion.fill(blockChanged: true, reduceMotion: false) == nil)
    }

    @Test("Reduce Motion steps instead of sliding, and still jumps")
    func reduceMotionNeverAnimates() {
        #expect(LoopMotion.fill(blockChanged: false, reduceMotion: true) == nil)
        #expect(LoopMotion.fill(blockChanged: true, reduceMotion: true) == nil)
    }

    @Test("The within-block animation is the linear one, not a spring")
    func withinABlockItIsLinear() {
        // A spring would overshoot a boundary the timer has not reached.
        #expect(LoopMotion.fill(blockChanged: false, reduceMotion: false) == LoopMotion.fill)
        #expect(LoopMotion.fill == .linear(duration: LoopMotion.tickInterval))
    }
}
