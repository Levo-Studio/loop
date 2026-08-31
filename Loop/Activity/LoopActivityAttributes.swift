import ActivityKit
import Foundation

// MARK: - Live Activity attributes

/// The payload of Loop's Live Activity, shared by the app and the widget
/// extension.
///
/// The type carries no stored attributes. Everything the lock screen and the
/// Dynamic Island draw can change while a run is going — the block, the round,
/// the window being counted, the accent — so all of it lives in `ContentState`,
/// where an update can reach it. An attribute is for what cannot change, and
/// Loop has none.
///
/// This file is compiled into both targets. It is the only shape the two agree
/// on, which is why it holds no view code and no engine code: the app maps a
/// timer snapshot onto it, the widget maps it onto a frame, and neither has to
/// know the other's types.
nonisolated struct LoopActivityAttributes: ActivityAttributes {

    // MARK: - Block

    /// Which of the two timers is running, and which block of it.
    ///
    /// The countdown is a block in its own right rather than a special case
    /// with a `nil` round: one enum keeps the widget's `switch` exhaustive, and
    /// the day a third timer grows a duration it is one case here rather than a
    /// second optional everywhere.
    enum Block: String, Codable, Hashable, Sendable {
        case countdown
        case focus

        /// `break` is a keyword; the raw value is what crosses the wire and it
        /// keeps the engine's spelling.
        case rest = "break"
    }

    // MARK: - Content state

    /// One frame of the Live Activity, derived from the same timer snapshot the
    /// screen draws from.
    ///
    /// The state is **not** a remaining time. A remaining time would be a lie
    /// one second after it was written, and correcting it would mean pushing an
    /// update every second — which ActivityKit throttles and drops. What is
    /// stored instead is the *window* the current block occupies in wall time,
    /// which stays true without anything being awake: iOS counts down inside it
    /// on its own through `Text(timerInterval:pauseTime:)` and
    /// `ProgressView(timerInterval:)`.
    struct ContentState: Codable, Hashable, Sendable {

        let block: Block

        /// 1-based round and the total, for "Focus · Round 02 / 04". Both are
        /// `1` on a countdown, which has no rounds; the countdown layout never
        /// reads them.
        let round: Int
        let rounds: Int

        /// The wall-clock span of the **current** block: when it began and when
        /// it will end. iOS animates inside this range without an update.
        ///
        /// A resume writes a new window shifted forward by however long the run
        /// was held, because the block now ends later. That is the whole of the
        /// pause handling on the app's side.
        let window: ClosedRange<Date>

        /// The instant the run was held, or `nil` while it is running.
        ///
        /// `Text(timerInterval:pauseTime:)` freezes its digits here, so a held
        /// timer stops on the lock screen instead of running on — the failure
        /// this field exists to prevent.
        let pausedAt: Date?

        /// `LoopAccent.rawValue`.
        ///
        /// The accent reaches the widget in the content state rather than
        /// through a shared container. ActivityKit already delivers this
        /// payload from the app to the extension, so an App Group — and the
        /// entitlement and the registered group identifier it drags in — buys
        /// nothing. It is stored as the raw value rather than as `LoopAccent`
        /// so a preference written by a newer build decodes into the default
        /// instead of failing the whole state.
        let accentID: String

        // MARK: - Derived

        var isPaused: Bool { pausedAt != nil }

        /// The length of the current block.
        var duration: TimeInterval {
            window.upperBound.timeIntervalSince(window.lowerBound)
        }

        /// Whether the digits carry an hour field.
        ///
        /// Decided by the block's own length rather than by the value being
        /// drawn, so `1:00:00` does not become `59:59` a second later and take
        /// the layout with it.
        var showsHours: Bool { duration >= 3_600 }

        /// The height of the rising area at the instant the run was held.
        ///
        /// Only a held run needs this. A running one hands the window to
        /// `ProgressView(timerInterval:)` and lets iOS move it; a held one has
        /// no moving value at all, and a progress view that kept advancing
        /// under frozen digits is the same bug from the other side.
        var pausedFraction: Double {
            guard let pausedAt, duration > 0 else { return 0 }
            let elapsed = pausedAt.timeIntervalSince(window.lowerBound)
            return min(1, max(0, elapsed / duration))
        }
    }
}
