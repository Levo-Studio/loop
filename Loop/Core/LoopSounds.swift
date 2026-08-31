import AudioToolbox
import Foundation

// MARK: - Sounds

/// The three tones the app plays, and the only audio in Loop.
///
/// iOS system sounds, no bundled assets: a study timer that ships its own
/// samples has to carry a licence, a volume balance and a set of files that
/// age badly next to the system's own. `AudioServicesPlaySystemSound` costs one
/// call and one identifier, and the tones are already familiar to anyone
/// holding an iPhone.
///
/// Imperative, like `LoopHaptics`, and for the same reason: a value-watching
/// modifier installed inside `FillSurface`'s content is installed twice,
/// because that content is built twice for the two-tone layers, and a tone
/// played twice is a tone played once at double volume. Firing from the place
/// that observed the transition happens once.
///
/// **What governs whether anything is heard**
///
/// - A system sound is an *alert*, not media. It is played at the "Ringer and
///   Alerts" volume, not the media volume, and it is silenced by the
///   Ring/Silent switch — with the switch on silent nothing is heard, and on
///   iPad the same holds for silent mode in Control Centre. There is no way
///   around that short of claiming an `AVAudioSession` with `.playback`, which would make Loop's tones media
///   audio and let them interrupt or duck whatever the user is listening to
///   while they work. That trade is not worth a boundary beep, so Loop claims
///   no audio session at all and accepts the silent switch.
/// - `AudioServicesPlaySystemSound` does **not** vibrate. That is deliberate:
///   `AudioServicesPlayAlertSound` would add a system vibration on top, and
///   Loop already decides its own haptics in `LoopHaptics`.
/// - Do Not Disturb and Focus suppress *notification delivery*. They do not
///   silence audio a foreground app plays, so a tone is still heard under a
///   Focus mode as long as the ringer is on. Users expect the opposite, which
///   is why it is written down here.
/// - Nothing mixes badly: system sounds play over other audio rather than
///   pausing it.
///
/// **Background is the limitation, and it is a real one.** Loop has no audio
/// background mode and starts no background task, so iOS suspends it seconds
/// after it leaves the screen. Suspended code does not run, so no tone fires
/// for a boundary that passes while the app is backgrounded or the screen is
/// locked. The timers themselves are unaffected — they derive everything from
/// `Date`, so the app comes back on the correct block — but the tones for the
/// boundaries that went by are gone, and replaying them on return would fire a
/// burst of beeps for something that happened twenty minutes ago. Making a
/// boundary audible with the app closed needs scheduled local notifications or
/// a Live Activity alert; neither is this layer's job.
enum LoopSounds {

    // MARK: - Cues

    /// What happened, not which file plays it. A screen names the event; the
    /// mapping to an identifier lives here so two screens cannot pick two
    /// different tones for the same moment.
    ///
    /// A block boundary is a single instant: one block ends exactly as the next
    /// begins. If a screen plays both halves of the pair there, they are heard
    /// as one two-part figure rather than as a smear — see `play(_:enabled:)`.
    /// Whether a boundary should say both things or only the more useful one is
    /// the caller's decision, and this layer does not make it.
    /// `nonisolated`, unlike the layer around it: a cue is a plain value with
    /// no state, and a test that only wants to see three different identifiers
    /// should not have to be on the main actor for it.
    nonisolated enum Cue: Sendable, CaseIterable {

        /// An interval focus or break block has finished.
        case blockEnded

        /// The next block has started.
        case blockBegan

        /// A countdown has reached zero, or an interval has run out its last
        /// round.
        case timerFinished

        /// The system sound to play.
        ///
        /// The identifiers are the system's `UISounds` catalogue. The three are
        /// picked to be told apart with the phone face down on a desk, which is
        /// the only situation any of this is for:
        ///
        /// - `1114` is `end_record.caf`: two notes, A5 then D6, rising, 0.43 s.
        ///   A *figure* — the ear hears two events.
        /// - `1113` is `begin_record.caf`: one plain note at D6, 0.45 s. A
        ///   *single* event, at the pitch the other one lands on.
        /// - `1005` is `alarm.caf`: 2.0 s, melodic, four times longer than
        ///   either and unmistakably an ending rather than a step.
        ///
        /// So the pair differs in shape (two notes against one) and in where it
        /// starts (a fifth below against straight in), and the finish differs
        /// from both in length by a factor of four. Three tones from the same
        /// alert family, so they share loudness and timbre and only the thing
        /// that carries the meaning changes.
        var identifier: SystemSoundID {
            switch self {
            case .blockEnded: 1114
            case .blockBegan: 1113
            case .timerFinished: 1005
            }
        }

        /// How long the tone runs, measured off the files themselves.
        ///
        /// Needed only so a second cue fired in the same instant can wait for
        /// the first. `AudioServicesPlaySystemSound` returns immediately and
        /// tells nobody when it is done, so the length has to be known here.
        var length: TimeInterval {
            switch self {
            case .blockEnded: 0.43
            case .blockBegan: 0.46
            case .timerFinished: 2.03
            }
        }
    }

    // MARK: - Playing

    /// The instant the tone that is currently sounding will be finished.
    ///
    /// A block boundary hands this layer two cues at the same instant, and a
    /// countdown that finishes on a boundary can hand it a third. Played raw
    /// they overlap into one indistinct noise — exactly the thing the two tones
    /// exist to avoid. Queueing them costs one stored date and turns a smear
    /// into a sequence.
    private static var freeAt = Date.distantPast

    /// Plays a cue, unless the user has turned sound off.
    ///
    /// The switch is passed in rather than read from a global: the settings
    /// object is owned by the shell and handed down, and a second path to it
    /// from here would be the copy that eventually disagrees.
    static func play(_ cue: Cue, enabled: Bool) {
        guard enabled else { return }

        let now = Date.now
        let start = max(now, freeAt)
        freeAt = start.addingTimeInterval(cue.length)

        let wait = start.timeIntervalSince(now)
        guard wait > 0 else {
            AudioServicesPlaySystemSound(cue.identifier)
            return
        }

        let identifier = cue.identifier
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
            AudioServicesPlaySystemSound(identifier)
        }
    }
}
