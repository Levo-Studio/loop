import Foundation

// MARK: - Countdown

/// One duration, counted down.
///
/// The finish is not an event the app has to be awake for. It is a comparison
/// between the elapsed time and the duration, so a countdown that ran out while
/// the app was in the background comes back finished rather than sitting at a
/// negative remaining.
nonisolated struct CountdownTimer: Sendable, Codable, Equatable {

    // MARK: - Phase

    enum Phase: String, Sendable, Codable, CaseIterable {
        case idle
        case running
        case paused
        case finished
    }

    // MARK: - Snapshot

    /// Everything the countdown screen draws, read at a single instant.
    ///
    /// The screen must not ask for the phase, then the time, then the fraction:
    /// three calls are three different `now` values, and one that lands either
    /// side of the finish shows a full area under a running pill. One snapshot
    /// per frame settles the timer once and answers from that.
    ///
    /// Whether a control is live belongs here too, even though `canStart` does
    /// not depend on the instant today. It is read every frame to enable a
    /// button, it is the obvious thing to copy off the timer, and the day
    /// someone gives it a time-dependent condition the copy is wrong without a
    /// word of warning. The rule a screen can rely on: if it is drawn, it is on
    /// the snapshot.    ///
    /// A snapshot is one frame, frozen. It is safe as a binding's getter only
    /// because `body` rebuilds it on every pass; hoisted into a stored property
    /// it would go stale silently, showing a value the timer no longer holds.
    struct Snapshot: Sendable, Equatable {
        let phase: Phase

        /// The scale's value, for the "25 min" beside it. Writing goes through
        /// `setDuration(minutes:at:)`; a binding reads here and writes there.
        let durationMinutes: Int

        let duration: TimeInterval
        let remaining: TimeInterval

        /// Height of the rising area, 0…1.
        let fraction: Double

        /// Whether the start button is live. A zero-minute duration has nothing
        /// to count.
        let canStart: Bool
    }

    // MARK: - Storage

    /// Whole minutes on `LoopTimerLimits.duration` — up to thirty hours, to
    /// the minute below two and to five minutes above.
    private(set) var durationMinutes: Int

    /// The phase as last written. `running` here can still mean "finished by
    /// now" — every read runs it through `resolved(at:)` first.
    private var storedPhase: Phase

    private var tracker: ElapsedTracker

    // MARK: - Life cycle

    /// 25 minutes is the value the idle screen is drawn with, so it is what the
    /// scale starts at.
    init(durationMinutes: Int = 25) {
        self.durationMinutes = LoopTimerLimits.duration.nearest(to: durationMinutes)
        storedPhase = .idle
        tracker = ElapsedTracker()
    }

    // MARK: - Reading

    var duration: TimeInterval { TimeInterval(durationMinutes) * 60 }

    /// A zero-minute duration is reachable on the scale, and it has nothing to
    /// count. Rather than starting a timer that finishes in the same frame, the
    /// engine refuses to start it at all and the button stays disabled.
    ///
    /// Private, and reachable only as `snapshot(at:).canStart`. Leaving a
    /// second way in would leave the copy this was moved to prevent: the day
    /// the condition depends on the instant, a screen still reading it here
    /// would be wrong with nothing to warn it. There is no such risk in the
    /// scales — a binding legitimately writes through those — so they stay
    /// readable.
    private var canStart: Bool { durationMinutes > 0 }

    /// The whole readable state at one instant. This is what a screen draws
    /// from; the accessors below are conveniences for a single value.
    func snapshot(at now: Date) -> Snapshot {
        let resolved = resolved(at: now)
        let duration = resolved.duration
        let remaining = min(max(0, duration - resolved.tracker.elapsed(at: now)), duration)

        return Snapshot(
            phase: resolved.storedPhase,
            durationMinutes: resolved.durationMinutes,
            duration: duration,
            remaining: remaining,
            fraction: Self.fraction(phase: resolved.storedPhase, remaining: remaining, duration: duration),
            canStart: resolved.canStart
        )
    }

    func phase(at now: Date) -> Phase { snapshot(at: now).phase }

    func remaining(at now: Date) -> TimeInterval { snapshot(at: now).remaining }

    func fraction(at now: Date) -> Double { snapshot(at: now).fraction }

    /// The height of the rising area: 1 − remaining / duration.
    ///
    /// A timer that has not been started has no area at all. Reading the empty
    /// case as "full" is the mistake that puts a filled screen under a stopped
    /// timer, where it reads as a design choice and nobody reports it.
    private static func fraction(phase: Phase, remaining: TimeInterval, duration: TimeInterval) -> Double {
        switch phase {
        case .idle: 0
        case .finished: 1
        case .running, .paused: duration > 0 ? 1 - remaining / duration : 1
        }
    }

    // MARK: - Resolving

    /// The state with the time-driven transition applied.
    func resolved(at now: Date) -> CountdownTimer {
        guard storedPhase == .running, tracker.elapsed(at: now) >= duration else { return self }

        var resolved = self
        resolved.storedPhase = .finished

        // Freeze at exactly the duration, so a finished timer that is looked at
        // an hour later still reports 00:00 and a full area rather than drifting
        // on.
        resolved.tracker.set(elapsed: duration, at: now)
        resolved.tracker.pause(at: now)
        return resolved
    }

    /// Writes the transition into the value. The screen calls this on its tick
    /// so the change to `finished` is persisted and can trigger haptics; every
    /// read is correct without it.
    mutating func commitTransitions(at now: Date) { self = resolved(at: now) }

    // MARK: - Writing

    /// Only meaningful before a run: the scale is the idle screen. Returns
    /// whether the change was taken.
    @discardableResult
    mutating func setDuration(minutes: Int, at now: Date) -> Bool {
        commitTransitions(at: now)
        guard storedPhase == .idle else { return false }
        durationMinutes = LoopTimerLimits.duration.nearest(to: minutes)
        return true
    }

    /// Starts from idle, or restarts a finished run.
    @discardableResult
    mutating func start(at now: Date) -> Bool {
        commitTransitions(at: now)
        guard canStart, storedPhase == .idle || storedPhase == .finished else { return false }
        tracker.reset()
        tracker.start(at: now)
        storedPhase = .running
        return true
    }

    @discardableResult
    mutating func pause(at now: Date) -> Bool {
        commitTransitions(at: now)
        guard storedPhase == .running else { return false }
        tracker.pause(at: now)
        storedPhase = .paused
        return true
    }

    @discardableResult
    mutating func resume(at now: Date) -> Bool {
        commitTransitions(at: now)
        guard storedPhase == .paused else { return false }
        tracker.start(at: now)
        storedPhase = .running
        return true
    }

    /// Back to the setup state of the page, duration kept — the scale is where
    /// the user left it, and reset is not a way to lose that.
    mutating func reset() {
        tracker.reset()
        storedPhase = .idle
    }

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case durationMinutes
        case storedPhase
        case tracker
    }

    /// Written out rather than synthesised. A synthesised `init(from:)` would
    /// assign the stored properties straight from the record and skip the
    /// resolve above, which is the one promise this type makes about a damaged
    /// or older store. It is also the path that repairs a value that is in
    /// range but no longer on a detent: a record from before the scale was
    /// staged can hold 63 minutes, and that is snapped to 65 rather than
    /// dropped.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        durationMinutes = LoopTimerLimits.duration.nearest(
            to: try container.decode(Int.self, forKey: .durationMinutes)
        )
        storedPhase = try container.decode(Phase.self, forKey: .storedPhase)
        tracker = try container.decode(ElapsedTracker.self, forKey: .tracker)
    }
}
