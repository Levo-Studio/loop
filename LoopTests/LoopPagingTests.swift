import SwiftUI
import Testing

@testable import Loop

// MARK: - Paging

/// Turning the device must not change the page. That was a real bug — from the
/// interval page, portrait offset 1206 of 2010, a turn to landscape and back,
/// and the strip standing at 804, which is the countdown page — and the fix was
/// to stop letting the scroll position *be* the choice. These tests hold that
/// separation: every movement of the strip that is not a settled gesture is
/// geometry, and geometry does not choose a page.
@Suite("Paging")
struct LoopPagingTests {

    /// The phases a rotation drags the strip through before anything comes to
    /// rest. None of them may commit.
    nonisolated static let unsettled: [ScrollPhase] = [.tracking, .interacting, .decelerating, .animating]

    // MARK: - The invariant

    @Test("A change of size does not change the page", arguments: LoopPage.allCases)
    func resizeKeepsThePage(_ chosen: LoopPage) {
        var paging = LoopPaging()
        paging.scrollPhaseChanged(to: .idle, standingOn: chosen)

        // The resize itself. It asks where the strip belongs and is told the
        // page the user chose, which is the entire fix: nothing about the new
        // geometry is allowed to answer that question.
        #expect(paging.destinationAfterResize == chosen)
        #expect(paging.page == chosen)
    }

    @Test("The measured rotation leaves the interval page where it was")
    func theMeasuredRotation() {
        var paging = LoopPaging()
        paging.scrollPhaseChanged(to: .idle, standingOn: .interval)

        // Landscape. The strip is re-measured under the new page width and the
        // offset lands on a different page while the scroll view is still
        // moving — this is the movement that used to be read as a choice.
        for phase in Self.unsettled {
            paging.scrollPhaseChanged(to: phase, standingOn: .countdown)
        }

        #expect(paging.page == .interval)

        // Back to portrait, and the shell puts the strip back where the page
        // says. The re-assertion comes to rest on the page already held, so the
        // commit is a no-op rather than a second chance to get it wrong.
        paging.scrollPhaseChanged(to: .animating, standingOn: .countdown)
        paging.scrollPhaseChanged(to: .idle, standingOn: paging.destinationAfterResize)

        #expect(paging.page == .interval)
    }

    @Test("A strip that has not come to rest is not a choice", arguments: LoopPagingTests.unsettled)
    func unsettledIsNotAChoice(_ phase: ScrollPhase) {
        var paging = LoopPaging()
        paging.scrollPhaseChanged(to: .idle, standingOn: .interval)
        paging.scrollPhaseChanged(to: phase, standingOn: .settings)

        #expect(paging.page == .interval)
    }

    @Test("Without a page under it the strip says nothing, and the last choice stands")
    func nothingMeasuredYet() {
        var paging = LoopPaging()
        paging.scrollPhaseChanged(to: .idle, standingOn: .countdown)
        paging.scrollPhaseChanged(to: .idle, standingOn: nil)

        #expect(paging.page == .countdown)
    }

    // MARK: - What still has to work

    @Test("A settled swipe is a choice")
    func aSettledSwipeCommits() {
        var paging = LoopPaging()

        #expect(paging.page == .clock)

        // The swipe, phase by phase: nothing counts until it stops.
        paging.scrollPhaseChanged(to: .tracking, standingOn: .clock)
        paging.scrollPhaseChanged(to: .decelerating, standingOn: .countUp)
        paging.scrollPhaseChanged(to: .idle, standingOn: .countUp)

        #expect(paging.page == .countUp)
        #expect(paging.destinationAfterResize == .countUp)
    }

    @Test("The app opens on the clock")
    func startsOnTheClock() {
        #expect(LoopPaging().page == .clock)
    }
}
