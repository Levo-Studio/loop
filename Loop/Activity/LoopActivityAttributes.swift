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
/// **A Live Activity does not outlive a long run.** ActivityKit ends one about
/// eight hours after it starts and takes it off the lock screen at about
/// twelve, whatever the app does. The countdown scale goes to thirty hours, so a
/// run near the top of it loses its Live Activity around two-thirds of the way
/// through while the timer itself keeps going. The app stays the source of
/// truth; the empty lock screen is the system's decision, not a bug to hunt.
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

    // MARK: - Upcoming block

    /// A block the run has not reached yet.
    ///
    /// These are carried so the lock screen can roll over **without an update**.
    /// At a block boundary the app is very often suspended — that is the whole
    /// situation a Live Activity exists for — so the pushes that matter most are
    /// the ones that cannot be sent. Sending the rest of the schedule ahead of
    /// time is the only way the card can be right at instants the app will not
    /// be awake for.
    struct Upcoming: Codable, Hashable, Sendable {
        let block: Block
        let round: Int
        let window: ClosedRange<Date>
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
    /// on its own through `Text(timerInterval:pauseTime:)`.
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

        /// The blocks after this one, in order. Empty on a countdown, which is
        /// one block, and on the last focus block of a run.
        ///
        /// Bounded rather than unbounded; see
        /// `LoopActivityController.maxUpcomingBlocks` for the budget and the
        /// arithmetic behind the bound.
        let upcoming: [Upcoming]

        // MARK: - Derived

        var isPaused: Bool { pausedAt != nil }

        /// The frame to draw at `now`, once `now` is past the block this state
        /// was pushed for.
        ///
        /// **The block is chosen by time, never by staleness.**
        /// `ActivityViewContext.isStale` is a stored `Bool` baked into each
        /// render context, so once the stale instant has passed it reads `true`
        /// for every later render until new content arrives. Choosing on it
        /// alone would pin the card to the first block after the boundary and
        /// hold a wrong round number there indefinitely — worse than the frozen
        /// digits it was meant to cure, because a frozen `00:00` at least names
        /// the block it belongs to. `staleDate` is what gets the widget
        /// re-rendered; this is what decides what the re-render draws.
        ///
        /// A held run has none. Its window does not run out at all, because the
        /// digits are frozen, so there is nothing to roll over to.
        func rolledOver(at now: Date) -> ContentState? {
            guard !isPaused, now >= window.upperBound, !upcoming.isEmpty else { return nil }

            // The first block that has not ended yet, which is how the engine
            // reads its own schedule. Past everything carried, the last block is
            // the honest answer: its kind and round are right and its digits sit
            // at zero, rather than a round from an hour ago counting nothing.
            let block = upcoming.first { $0.window.upperBound > now } ?? upcoming[upcoming.count - 1]

            return ContentState(
                block: block.block,
                round: block.round,
                rounds: rounds,
                window: block.window,
                pausedAt: nil,
                accentID: accentID,
                // Dropped rather than carried: every render starts again from
                // the state the app pushed, so a roll-over is never itself
                // rolled over.
                upcoming: []
            )
        }

        /// The length of the current block.
        var duration: TimeInterval {
            window.upperBound.timeIntervalSince(window.lowerBound)
        }

        /// Whether the digits may carry an hour field.
        ///
        /// Decided by the block's own length rather than by what is left of it,
        /// because the flag has to be right for the whole block and the app is
        /// not awake to change it.
        ///
        /// It **permits** the hour field rather than holding it: iOS drops the
        /// hours once the value falls under an hour, so a block longer than an
        /// hour still narrows from `1:00:00` to `59:59` as it crosses. Rendering
        /// the text at a range of lengths is what showed this; passing `false`
        /// would be worse, since a two-hour block would then print `00:00` at
        /// the hour mark rather than merely changing width.
        ///
        /// Past twenty-four hours it does not wrap: a thirty-hour countdown —
        /// which the scale allows — prints `30:00:00`. That was checked with an
        /// in-process `ImageRenderer` render of the text, not on a lock screen.
        var showsHours: Bool { duration >= 3_600 }

        /// How many characters the digits can be at their longest.
        ///
        /// The compact Dynamic Island has to reserve room for the time
        /// *before* it exists: iOS draws the digits itself inside the window,
        /// so there is no string for a layout to measure. Left unreserved, the
        /// text asks for an ideal width unrelated to what it prints and the
        /// island stretches across the status bar — see
        /// `LoopActivityTypography.compactTimeWidth(characters:)`.
        ///
        /// Taken from the block's own length rather than from what is left of
        /// it, and for the same reason `showsHours` is: the value has to hold
        /// for the whole block, because the app is not awake to change it. A
        /// block that starts at `1:29:59` therefore keeps room for seven
        /// characters after it narrows to `59:59`, which is a still island
        /// rather than one that jumps a character narrower at the hour mark.
        var timeCharacters: Int {
            // "MM:SS" under an hour, "H:MM:SS" over it — with as many hour
            // digits as the block actually needs, so a 90-minute interval does
            // not reserve the width a thirty-hour countdown does.
            guard showsHours else { return 5 }

            return String(Int(duration / 3_600)).count + 6
        }
    }
}
