import SwiftUI

// MARK: - Paging

/// Which page the user chose, and what is allowed to change that answer.
///
/// A value rather than two lines inside `RootShell`, for the same reason
/// `LoopIdleTimer` and `LoopDismissal` are values: it is a rule with a wrong
/// answer, and the wrong answer is invisible until somebody turns a device. The
/// shell is left holding it and forwarding two events.
///
/// **The bug this exists to keep out is a rotation changing the page.** While
/// the chosen page *was* the scroll view's position, anything that moved the
/// strip counted as a choice — including the offset a resize settles on inside
/// content it is still re-measuring. Measured on an iPhone 17 Pro from the
/// interval page: portrait offset 1206 of 2010, and after a turn to landscape
/// and back, 804, which is the countdown page. The user turned the phone and
/// got a screen they never asked for.
///
/// So intent and position are kept apart. Only a gesture that has come to rest
/// writes the page; every other movement of the strip is geometry, not a
/// choice. A change of size does not decide anything at all — it only asks
/// where the strip belongs, and the answer is wherever the user last left it.
nonisolated struct LoopPaging: Equatable, Sendable {

    // MARK: - The answer

    /// The page the user chose. Only a settled scroll can change it.
    private(set) var page: LoopPage

    init(page: LoopPage = .clock) {
        self.page = page
    }

    /// Where the strip has to be put once the geometry has moved.
    ///
    /// The chosen page, unchanged — that is the whole invariant, and it is
    /// spelled out as a question the shell asks rather than left implicit in
    /// which variable the resize happens to read. A resize that returns
    /// anything else here is the rotation bug coming back.
    var destinationAfterResize: LoopPage {
        page
    }

    // MARK: - The rule

    /// What a change of the scroll view's phase makes of the chosen page.
    ///
    /// Only `.idle` commits. A strip that is still tracking, decelerating or
    /// being animated somewhere has not been chosen yet, and a clamp during a
    /// resize moves it without ever going through a phase at all — which is
    /// exactly the difference this guard is here to keep. Re-asserting the page
    /// after a resize therefore comes back through here and lands on the value
    /// that is already held, so the assignment is a no-op rather than a second
    /// chance to get it wrong.
    ///
    /// `nil` means the scroll view cannot yet say which page it is standing on.
    /// That is not a choice of the first page; it is no answer, and the last
    /// one stands.
    mutating func scrollPhaseChanged(to phase: ScrollPhase, standingOn landed: LoopPage?) {
        guard phase == .idle, let landed else { return }

        page = landed
    }
}
