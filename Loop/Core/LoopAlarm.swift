import UIKit

// MARK: - Alarm

/// The finished countdown's cue, sounded over and over until it is dismissed
/// or until it has been ringing for a quarter of an hour.
///
/// A single tone is a notification; an alarm is a tone that keeps asking. The
/// countdown is the one timer in Loop that is set to run out at a particular
/// moment, and the moment it exists for is the one where nobody is looking at
/// the screen — a duration that finishes in another room has to still be
/// audible when you get there. `LoopSounds` plays a cue; this decides how often
/// to ask it to, and for how long.
///
/// **Going quiet is not the same as being dismissed, and changes nothing on
/// screen.** The countdown is still finished, the slide-to-stop control is
/// still there and still the only way out of the state. Someone who comes back
/// twenty minutes late finds the page they would have found at one minute,
/// silent. The alarm is the part that gives up; the acknowledgement it was
/// asking for is still owed.
///
/// It owns no audio of its own. Every repetition goes through
/// `LoopSounds.play(_:enabled:)` exactly as a one-off cue does, which is what
/// keeps the session handling in one place: the session is activated around a
/// cue and released a quarter of a second after it, so the gap between two
/// soundings is a gap in which Loop holds nothing. An alarm that latched the
/// session open would dip the user's music for as long as it rang, and it could
/// ring for a while.
///
/// Imperative and static, like `LoopSounds` and `LoopHaptics`, and for the same
/// reason: the screens live inside `FillSurface`'s twice-built content, so
/// anything that starts or stops this has to be fired from the one place that
/// observed the transition rather than installed as a modifier.
enum LoopAlarm {

    // MARK: - Cadence

    /// Which cue repeats, and how much silence sits between two soundings.
    ///
    /// A value rather than two constants, so the cadence can be reasoned about
    /// — and tested — without an audio device, a session or a simulator. Pure
    /// `Foundation` arithmetic over a cue that is itself pure arithmetic.
    nonisolated struct Schedule: Sendable, Equatable {

        /// The cue sounded on every repetition.
        let cue: LoopSounds.Cue

        /// The silence between the end of one sounding and the start of the
        /// next.
        let gap: TimeInterval

        /// How long the alarm goes on ringing before it gives up.
        let limit: TimeInterval

        /// The finished countdown's alarm.
        ///
        /// The gap is a **cadence, not a design value**: nothing about it is
        /// drawn, the export cannot contain it, and it belongs to the thing
        /// that does the waiting. It is chosen against the cue it repeats
        /// rather than picked round.
        ///
        /// `timerFinished` is a 1.75 s arpeggio whose last note is **held for
        /// 0.91 s**, and that held note is what identifies the figure from the
        /// next room. A gap shorter than it reads as the figure being cut off
        /// and started again — a stutter — because the ear has not yet heard
        /// the tone stop before the next one begins. So the gap has to clear
        /// the held note, and 1.25 s does, with the note's own decay finishing
        /// inside the silence rather than against the following attack.
        ///
        /// That puts a repetition every 3 s. Long enough that each sounding is
        /// a separate event and short enough that the pause is never mistaken
        /// for the alarm having given up — which is the failure at the other
        /// end, and the one that gets a timer ignored.
        ///
        /// **The limit is fifteen minutes, and it is borrowed rather than
        /// chosen.** The brief for this feature was that the countdown behaves
        /// like the iOS timer, and the iOS timer stops sounding on its own
        /// after about a quarter of an hour rather than ringing until somebody
        /// arrives. Matching it is the whole point: a user who has met the
        /// system's alarm knows how long this one will go on without being
        /// told, and a number picked here instead would be a second answer to a
        /// question the platform has already answered.
        ///
        /// Two honest notes on the figure. Apple documents no such interval —
        /// it is what the system timer is observed to do, not a published
        /// contract — so this is a deliberate imitation of behaviour rather
        /// than a value read off a spec. And like the gap it is a **cadence,
        /// not a design value**: nothing about it is drawn and the export
        /// cannot contain it.
        ///
        /// What it is for is the case nobody is present for. An alarm with no
        /// one to hear it has stopped being an alarm and become a phone lying
        /// face up on a desk, ringing and ducking whatever else that phone was
        /// playing, for as long as the battery lasts.
        static let finished = Schedule(cue: .timerFinished, gap: 1.25, limit: 15 * 60)

        /// One sounding plus the silence after it.
        var period: TimeInterval { cue.tone.duration + gap }

        /// When the `repetition`-th sounding is due, counted from the first.
        ///
        /// Derived from the instant the alarm began rather than accumulated
        /// from the previous wake, for the same reason the screens derive the
        /// time from `Date` instead of counting ticks: scheduling slop added to
        /// itself every three seconds turns a steady alarm into a drifting one.
        func due(repetition: Int, from start: Date) -> Date {
            start.addingTimeInterval(period * Double(repetition))
        }

        /// Whether the sounding due at `due` falls past the limit — that is,
        /// whether the alarm has rung for long enough and should give up.
        ///
        /// Measured from `start` and nothing else. `due` is itself derived from
        /// `start`, so the answer cannot drift with the repetitions the way a
        /// countdown of soundings would: it is the same subtraction on the
        /// first repetition as on the three-hundredth, and a wake that arrived
        /// late does not buy the alarm extra time.
        func isOver(due: Date, from start: Date) -> Bool {
            due.timeIntervalSince(start) > limit
        }

        /// Whether a wake that arrived at `now` for a sounding due at `due` is
        /// too late to be worth playing.
        ///
        /// The tolerance is `LoopSounds.lateness` rather than a second number
        /// with the same value: it measures the same thing — scheduler jitter
        /// against a suspension — and two names for it would drift apart.
        ///
        /// What it catches is the app coming back after being suspended. iOS
        /// suspends Loop seconds after it leaves the screen, and a suspended
        /// sleep resumes whenever the app is next foregrounded. Without this a
        /// countdown that finished twenty minutes ago would start ringing the
        /// instant it is opened, before anyone has read what it says.
        func isStale(due: Date, at now: Date) -> Bool {
            now.timeIntervalSince(due) > LoopSounds.lateness
        }
    }

    // MARK: - Sounding

    /// The repetition loop, or `nil` when nothing is ringing. Cancelling it is
    /// what stops the alarm.
    private static var repeating: Task<Void, Never>?

    private static var isObserving = false

    /// Starts ringing, replacing anything already ringing.
    ///
    /// The sound switch is passed in rather than read from a global, exactly as
    /// `LoopSounds.play(_:enabled:)` takes it: the settings object belongs to
    /// the shell and is handed down. With sound off nothing is heard — but the
    /// finished state still has to be dismissed, because the dismissal is a
    /// rule about the countdown and not a consequence of the audio.
    static func start(_ schedule: Schedule = .finished, enabled: Bool) {
        stop()
        guard enabled else { return }

        observeBackground()

        let begun = Date.now
        repeating = Task { @MainActor in
            var repetition = 0

            while !Task.isCancelled {
                LoopSounds.play(schedule.cue, enabled: enabled)
                repetition += 1

                let due = schedule.due(repetition: repetition, from: begun)

                // The quarter of an hour is up and the sounding that just
                // started is the last one. It is left to ring out rather than
                // cut short: the alarm is giving up, which is not the same
                // event as being dismissed and must not sound like it.
                guard !schedule.isOver(due: due, from: begun) else { break }

                let wait = due.timeIntervalSinceNow
                if wait > 0 {
                    try? await Task.sleep(for: .seconds(wait))
                }

                guard !Task.isCancelled, !schedule.isStale(due: due, at: .now) else { break }
            }

            // The alarm ended itself — it ran out its limit, or came back from
            // a suspension too late to be worth sounding. Either way nothing
            // is holding the slot any more, so it is given up here rather than
            // left pointing at a task that has finished.
            //
            // **Only when this loop was not cancelled.** A cancelled loop was
            // stopped or replaced by someone who already owns the slot, and
            // clearing it here would drop a run that has become somebody
            // else's — including the one a `start()` had just put there.
            if !Task.isCancelled { repeating = nil }
        }
    }

    /// Stops ringing and cuts whatever is sounding at that instant.
    ///
    /// The guard is not an optimisation. Countdown and Interval are adjacent
    /// pages and both are alive during a swipe between them, so this is called
    /// while the other screen may be sounding a boundary cue of its own —
    /// silencing the audio layer when this alarm was not ringing would cut a
    /// tone that has nothing to do with it.
    static func stop() {
        guard let repeating else { return }
        self.repeating = nil
        repeating.cancel()

        // Cancelling only ends the loop; the sounding it already started runs
        // to its full 1.75 s. A dismissal has to be instant, so the cue in
        // flight is cut rather than left to finish over the state it dismissed.
        LoopSounds.silence()
    }

    // MARK: - Leaving the app

    /// Stops the alarm when the app is backgrounded, and does not resume it.
    ///
    /// Loop declares no audio background mode, so a suspended repetition does
    /// not sound anyway — but the sleep it is suspended inside resumes on
    /// return, and an alarm that picks up again for a countdown that finished
    /// during a phone call is the burst of beeps `LoopSounds` argues against
    /// for boundaries. `Schedule.isStale(due:at:)` would catch it a moment
    /// later; this ends it at the transition instead, which is the instant it
    /// is actually known.
    ///
    /// Registered once and never removed: this layer lives as long as the
    /// process does, so there is nothing to remove it for.
    private static func observeBackground() {
        guard !isObserving else { return }
        isObserving = true

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { stop() }
        }
    }
}
