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

    // MARK: - Storage

    /// Whole minutes, 0…60, matching the scale on the idle screen.
    private(set) var durationMinutes: Int

    /// The phase as last written. `running` here can still mean "finished by
    /// now" — every read runs it through `settled(at:)` first.
    private var storedPhase: Phase

    private var tracker: ElapsedTracker

    // MARK: - Life cycle

    /// 25 minutes is the value the idle screen is drawn with, so it is what the
    /// scale starts at.
    init(durationMinutes: Int = 25) {
        self.durationMinutes = LoopTimerLimits.clamp(durationMinutes, to: LoopTimerLimits.durationMinutes)
        storedPhase = .idle
        tracker = ElapsedTracker()
    }

    // MARK: - Reading

    var duration: TimeInterval { TimeInterval(durationMinutes) * 60 }

    /// A zero-minute duration is reachable on the scale, and it has nothing to
    /// count. Rather than starting a timer that finishes in the same frame, the
    /// engine refuses to start it at all and the button stays disabled.
    var canStart: Bool { durationMinutes > 0 }

    func phase(at now: Date) -> Phase { settled(at: now).storedPhase }

    func remaining(at now: Date) -> TimeInterval {
        let settled = settled(at: now)
        return min(max(0, settled.duration - settled.tracker.elapsed(at: now)), settled.duration)
    }

    /// The height of the rising area: 1 − remaining / duration.
    func fraction(at now: Date) -> Double {
        guard duration > 0 else { return 1 }
        return 1 - remaining(at: now) / duration
    }

    // MARK: - Settling

    /// The state with the time-driven transition applied.
    func settled(at now: Date) -> CountdownTimer {
        guard storedPhase == .running, tracker.elapsed(at: now) >= duration else { return self }

        var settled = self
        settled.storedPhase = .finished

        // Freeze at exactly the duration, so a finished timer that is looked at
        // an hour later still reports 00:00 and a full area rather than drifting
        // on.
        settled.tracker.set(elapsed: duration, at: now)
        settled.tracker.pause(at: now)
        return settled
    }

    /// Commits the transition. The screen calls this on its tick so the change
    /// to `finished` is persisted and can trigger haptics; every read is
    /// correct without it.
    mutating func settle(at now: Date) { self = settled(at: now) }

    // MARK: - Writing

    /// Only meaningful before a run: the scale is the idle screen. Returns
    /// whether the change was taken.
    @discardableResult
    mutating func setDuration(minutes: Int, at now: Date) -> Bool {
        settle(at: now)
        guard storedPhase == .idle else { return false }
        durationMinutes = LoopTimerLimits.clamp(minutes, to: LoopTimerLimits.durationMinutes)
        return true
    }

    /// Starts from idle, or restarts a finished run.
    @discardableResult
    mutating func start(at now: Date) -> Bool {
        settle(at: now)
        guard canStart, storedPhase == .idle || storedPhase == .finished else { return false }
        tracker.reset()
        tracker.start(at: now)
        storedPhase = .running
        return true
    }

    @discardableResult
    mutating func pause(at now: Date) -> Bool {
        settle(at: now)
        guard storedPhase == .running else { return false }
        tracker.pause(at: now)
        storedPhase = .paused
        return true
    }

    @discardableResult
    mutating func resume(at now: Date) -> Bool {
        settle(at: now)
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
}
