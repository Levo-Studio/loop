import AVFoundation
import Foundation

// MARK: - Sounds

/// The three tones the app plays, and the only audio in Loop.
///
/// **Why this is real playback and not a system sound.** The obvious
/// implementation is `AudioServicesPlaySystemSound` with a system identifier:
/// one call, no assets, and it is what this layer did first. It was replaced
/// once the owner ruled that the Ring/Silent switch must not silence Loop —
/// and the reason is not that a system sound was measured to be muted. It is
/// that nobody can say either way.
///
/// What is **documented**: the `.playback` category continues to play with the
/// Silent switch set to silent. Apple states it.
///
/// What is **not documented, in either direction**: whether
/// `AudioServicesPlaySystemSound` obeys the switch, and whether an audio
/// session influences it at all. Apple documents neither. Developer reports
/// contradict each other, some of them specifically about the alert-family
/// identifiers this layer used. It was **not** verified on a muted device
/// here: the Simulator has no Ring/Silent switch and does not emulate one, and
/// no physical device was reachable. So the previous version of this comment,
/// which asserted the muting as fact, was inference presented as observation.
///
/// A requirement that a tone is heard on a muted phone therefore cannot rest on
/// the system-sound path, whatever that path happens to do on today's build:
/// undocumented behaviour is not a guarantee, and this is the one moment the
/// feature exists for. `.playback` is the only mechanism Apple commits to, and
/// real playback needs real samples — so `LoopTone` synthesises the three cues.
/// See the reasoning there for why synthesised rather than bundled.
///
/// If someone does put this on a muted device and finds the system sounds
/// audible, that is worth knowing but does not by itself justify going back.
///
/// **What governs whether anything is heard, under this mechanism**
///
/// - The `.playback` category is not silenced by the Ring/Silent switch. A cue
///   is heard on a muted phone, which is the point, and this one is documented
///   rather than inferred.
/// - It is still governed by the media volume. Volume at zero is silence, and
///   no category changes that — the switch is what was overridden, not the
///   volume control.
/// - Do Not Disturb and Focus suppress *notification delivery*. They have never
///   governed audio an app plays itself, and that is if anything more true here
///   than it was of a system sound: this is ordinary media playback, the same
///   path a music app uses, and a Focus mode does not stop music. So a cue
///   should be heard under Focus — but that one is reasoned from the analogy,
///   not established. Apple does not document the case, and nobody has put Loop
///   under a Focus mode with a `.playback` session active and listened. Unlike
///   the switch above, it is an expectation.
///
/// **Background is the limitation, and it is unchanged by any of this.** Loop
/// declares no `audio` background mode and starts no background task, so iOS
/// suspends it seconds after it leaves the screen. Suspended code does not run,
/// so no cue fires for a boundary that passes while the app is backgrounded or
/// the screen is locked. The timers are unaffected — they derive everything
/// from `Date`, so the app returns on the correct block — but the tones for the
/// boundaries that went by are gone, and replaying them on return would fire a
/// burst of beeps for something that happened twenty minutes ago. Making a
/// boundary audible with the app closed needs scheduled local notifications or
/// a Live Activity alert. Neither is this layer's job, and adding the audio
/// background mode would not fix it either: that mode keeps an app alive while
/// it is *already playing*, not while it waits twenty-five minutes to play.
///
/// Two honest qualifications on that. Suspension is not instant — there is a
/// short grace window after the app leaves the screen in which a boundary still
/// fires normally. And on iPadOS a Loop window in Split View or Stage Manager
/// is foreground-running, not suspended, so its boundaries sound exactly as
/// they do full screen.
///
/// Imperative, like `LoopHaptics`, and for the same reason: a value-watching
/// modifier installed inside `FillSurface`'s content is installed twice,
/// because that content is built twice for the two-tone layers, and a tone
/// played twice is a tone played once at double volume. Firing from the place
/// that observed the transition happens once.
enum LoopSounds {

    // MARK: - Cues

    /// What happened, not how it sounds. A screen names the event; the mapping
    /// to a figure lives in `LoopTone` so two screens cannot pick two different
    /// tones for the same moment.
    ///
    /// A block boundary is a single instant: one block ends exactly as the next
    /// begins. If a screen plays both halves of the pair there, they are heard
    /// as one two-part figure rather than as a smear — see `play(_:enabled:)`.
    /// Whether a boundary should say both things or only the more useful one is
    /// the caller's decision, and this layer does not make it.
    ///
    /// `nonisolated`, unlike the layer around it: a cue is a plain value with
    /// no state, and a test that only wants to compare two figures should not
    /// have to be on the main actor for it.
    nonisolated enum Cue: Sendable, CaseIterable, Hashable {

        /// An interval focus or break block has finished.
        case blockEnded

        /// The next block has started.
        case blockBegan

        /// A countdown has reached zero, or an interval has run out its last
        /// round.
        case timerFinished

        var tone: LoopTone {
            switch self {
            case .blockEnded: .blockEnded
            case .blockBegan: .blockBegan
            case .timerFinished: .timerFinished
            }
        }
    }

    // MARK: - Audio format

    /// 44.1 kHz mono. The engine resamples to whatever the hardware wants, and
    /// nothing here goes near the Nyquist limit of even half this rate.
    private static let sampleRate = 44_100.0

    private static let engine = AVAudioEngine()
    private static let player = AVAudioPlayerNode()

    /// Rendered once each and kept. Three short buffers is a few hundred
    /// kilobytes, and synthesising one on the main thread at the exact instant
    /// a block ends is the one moment that cannot afford it.
    private static var cache: [Cue: AVAudioPCMBuffer] = [:]

    private static var isWired = false
    private static var isObserving = false

    // MARK: - Playing

    /// The instant the cue that is currently sounding will be finished.
    ///
    /// A block boundary hands this layer two cues at the same instant, and a
    /// countdown that finishes on a boundary can hand it a third. Played raw
    /// they overlap into one indistinct noise — exactly the thing the two tones
    /// exist to avoid. Queueing them costs one stored date and turns a smear
    /// into a sequence.
    private static var freeAt = Date.distantPast

    /// Drops the audio session once the last cue has finished sounding.
    ///
    /// Held as a task so a cue arriving during the tail can cancel it. Loop
    /// must not sit on the audio system between beeps: an app holding an active
    /// `.playback` session with `.duckOthers` keeps everyone else's audio
    /// quiet, and a study timer that permanently dips the music it is supposed
    /// to be running alongside would be reported as a bug in the music app.
    private static var release: Task<Void, Never>?

    /// How long after the last sample to let go of the session.
    ///
    /// Long enough that the tail of the final note is not cut by the
    /// deactivation, short enough that ducking lifts while the cue is still the
    /// most recent thing you heard.
    private static let releaseDelay = 0.25

    /// How late a cue may be and still be worth playing.
    ///
    /// A fixed window rather than the cue's own length. What is being measured
    /// is jitter and suspension, neither of which knows how long the tone is,
    /// and scaling by duration would hand the finish four times the tolerance
    /// of a boundary — the most permissive treatment to the cue that matters
    /// most. Half a second is longer than any plausible hop between runloop
    /// turns and far shorter than a trip through the background.
    private static let lateness = 0.5

    /// Plays a cue, unless the user has turned sound off.
    ///
    /// The switch is passed in rather than read from a global: the settings
    /// object is owned by the shell and handed down, and a second path to it
    /// from here would be the copy that eventually disagrees.
    static func play(_ cue: Cue, enabled: Bool) {
        guard enabled else { return }

        let now = Date.now
        let start = max(now, freeAt)
        freeAt = start.addingTimeInterval(cue.tone.duration)

        let wait = start.timeIntervalSince(now)
        let quietAt = freeAt

        release?.cancel()
        release = nil

        if wait > 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(wait))

                // `start` already accounts for the queue — it is the instant
                // this cue is due once the one before it has finished — so
                // anything past it is scheduler jitter or the app having been
                // suspended mid-sleep. Waking twenty minutes later and beeping
                // for a boundary long gone is the burst this file argues
                // against above.
                guard Date.now.timeIntervalSince(start) <= lateness else { return }
                emit(cue)
            }
        } else {
            emit(cue)
        }

        release = Task { @MainActor in
            let idle = quietAt.timeIntervalSinceNow + releaseDelay
            if idle > 0 {
                try? await Task.sleep(for: .seconds(idle))
            }
            guard !Task.isCancelled else { return }
            stop()
        }
    }

    // MARK: - The audio session

    /// Activates the session, starts the engine and schedules the cue.
    ///
    /// Every failure here is swallowed. There is no recovery a user would want
    /// — the alternative to a beep that did not play is a dialog about an audio
    /// session, which is worse — and nothing else in Loop depends on it.
    private static func emit(_ cue: Cue) {
        guard let buffer = buffer(for: cue) else { return }

        let session = AVAudioSession.sharedInstance()

        // `.playback` is what ignores the Ring/Silent switch; `.duckOthers` is
        // the concession that makes it bearable. The alternative is
        // `.mixWithOthers`, which lays the cue over the music untouched — and a
        // 0.3-second sine under a track at working volume is exactly the cue
        // nobody notices, which defeats the feature. Ducking dips the music for
        // the length of the cue and lifts again; the dip itself is part of what
        // makes the boundary noticeable, and it never stops or steals the
        // user's audio the way an uncategorised interruption would.
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)

        wire(buffer.format)
        try? engine.start()

        guard engine.isRunning else {
            // Starting failed, which most often means the graph outlived the
            // route it was built for. Drop it rather than latching a connection
            // that will fail identically every time from here on.
            invalidate()
            return
        }

        player.play()
        player.scheduleBuffer(buffer, at: nil, options: [])
    }

    /// Stops the engine and hands the audio system back.
    ///
    /// `.notifyOthersOnDeactivation` is what tells whatever was ducked that it
    /// may come back up. Without it the music stays dipped until something else
    /// happens to nudge the session, which reads as Loop having broken the
    /// user's audio.
    private static func stop() {
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// Attaches and connects the player once. Reconnecting on every cue would
    /// tear down and rebuild the graph in the instant the sound is due.
    private static func wire(_ format: AVAudioFormat) {
        observeTeardowns()

        guard !isWired else { return }
        isWired = true

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    /// Forgets the graph, so the next cue builds a fresh one.
    ///
    /// The flag exists to avoid rebuilding the graph in the instant a sound is
    /// due; it must not become a claim that the graph is still valid. Apple
    /// documents that a configuration change tears down connections to the
    /// output node, and a latched `isWired` would leave the player attached to
    /// an output that no longer exists — `engine.start()` then fails and every
    /// later cue returns silently, for the rest of the process. Unplugging
    /// headphones would kill the feature until relaunch, with nothing to see.
    private static func invalidate() {
        player.stop()
        engine.stop()

        guard isWired else { return }
        isWired = false

        engine.disconnectNodeOutput(player)
        engine.detach(player)
    }

    /// Watches for the two things that take the graph or the session away.
    ///
    /// Registered once and never removed: this layer lives as long as the
    /// process does, so there is nothing to remove it for.
    private static func observeTeardowns() {
        guard !isObserving else { return }
        isObserving = true

        let center = NotificationCenter.default

        // A route change — headphones pulled, Bluetooth leaving, a call
        // arriving — is delivered as a configuration change, and the engine's
        // connections to the output node do not survive it.
        center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { invalidate() }
        }

        // An interruption deactivates the session underneath us. Rebuilding on
        // the next cue is right either way, and Loop has nothing to resume:
        // a cue is under two seconds, so whatever was interrupted is over.
        center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { invalidate() }
        }
    }

    // MARK: - Buffers

    private static func buffer(for cue: Cue) -> AVAudioPCMBuffer? {
        if let cached = cache[cue] { return cached }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return nil
        }

        let samples = cue.tone.samples(sampleRate: sampleRate)
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: format,
                  frameCapacity: AVAudioFrameCount(samples.count)
              ),
              let channel = buffer.floatChannelData?[0]
        else {
            return nil
        }

        for (index, sample) in samples.enumerated() {
            channel[index] = sample
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)

        cache[cue] = buffer
        return buffer
    }
}
