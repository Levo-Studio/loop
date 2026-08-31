import Testing

@testable import Loop

// MARK: - Dismissal

/// The rule two screens read and neither one owns.
///
/// It is four lines of `switch`, which is exactly why it is worth pinning: the
/// interval ignoring a setting the countdown obeys looks like an oversight to
/// anyone reading the call site, and the obvious "tidy-up" is to pass the
/// setting through to both.
@Suite("Dismissal")
struct LoopDismissalTests {

    @Test("A finished countdown waits for a swipe only while the setting is on")
    func countdown() {
        #expect(LoopDismissal.requiresSwipe(.countdown, swipeToDismissEnabled: true))
        #expect(!LoopDismissal.requiresSwipe(.countdown, swipeToDismissEnabled: false))
    }

    @Test("A finished interval never waits for a swipe, whatever the setting says")
    func interval() {
        // The setting is on by default, so this is the case that breaks first
        // if the interval is ever wired to it.
        #expect(!LoopDismissal.requiresSwipe(.interval, swipeToDismissEnabled: true))
        #expect(!LoopDismissal.requiresSwipe(.interval, swipeToDismissEnabled: false))
    }

    @Test("Only the countdown is affected by the setting at all")
    func onlyTheCountdownReactsToTheSetting() {
        // Written over `allCases` so a third finished timer added later has to
        // declare which side of the rule it is on rather than inheriting one.
        for timer in LoopDismissal.FinishedTimer.allCases {
            let on = LoopDismissal.requiresSwipe(timer, swipeToDismissEnabled: true)
            let off = LoopDismissal.requiresSwipe(timer, swipeToDismissEnabled: false)

            #expect(off == false, "nothing may demand a swipe once the setting is off")
            #expect((on != off) == (timer == .countdown))
        }
    }
}
