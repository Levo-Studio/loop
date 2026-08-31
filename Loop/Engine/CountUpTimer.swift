import Foundation

// MARK: - Count-up

/// The stopwatch: elapsed time and nothing else.
///
/// There is no total duration here, so there is no progress fraction and no
/// rising area — the design says so, and inventing one would need a made-up
/// maximum.
nonisolated struct CountUpTimer: Sendable, Codable, Equatable {

    // MARK: - Phase

    enum Phase: String, Sendable, Codable, CaseIterable {
        case idle
        case running
        case paused
    }

    // MARK: - Snapshot

    /// Everything one frame of the count-up screen needs, read at a single
    /// instant — the same shape the other two timers offer, so all three
    /// screens are written the same way.
    struct Snapshot: Sendable, Equatable {
        let phase: Phase
        let elapsed: TimeInterval

        /// The instant the run began, for the "since 09:29" line. `nil` while
        /// idle.
        let startDate: Date?
    }

    // MARK: - Storage

    private var tracker: ElapsedTracker

    /// The wall-clock instant the current run began, kept across a pause so the
    /// secondary line can say "since 09:29" rather than restating the last
    /// resume.
    private(set) var startDate: Date?

    // MARK: - Life cycle

    init() {
        tracker = ElapsedTracker()
        startDate = nil
    }

    // MARK: - Reading

    func snapshot(at now: Date) -> Snapshot {
        Snapshot(phase: currentPhase, elapsed: tracker.elapsed(at: now), startDate: startDate)
    }

    /// Takes an instant it does not need, so a screen reads all three timers
    /// the same way. The stopwatch has no time-driven transition: it never runs
    /// out, so nothing about its phase depends on when it is asked.
    func phase(at now: Date) -> Phase { currentPhase }

    func elapsed(at now: Date) -> TimeInterval { tracker.elapsed(at: now) }

    private var currentPhase: Phase {
        if tracker.isRunning { return .running }
        return startDate == nil ? .idle : .paused
    }

    // MARK: - Writing

    /// Begins a run. Resuming a held one is `resume(at:)` — start does not
    /// quietly do both, so a screen that calls the wrong one finds out.
    @discardableResult
    mutating func start(at now: Date) -> Bool {
        guard currentPhase == .idle else { return false }
        startDate = now
        tracker.start(at: now)
        return true
    }

    @discardableResult
    mutating func pause(at now: Date) -> Bool {
        guard currentPhase == .running else { return false }
        tracker.pause(at: now)
        return true
    }

    @discardableResult
    mutating func resume(at now: Date) -> Bool {
        guard currentPhase == .paused else { return false }
        tracker.start(at: now)
        return true
    }

    mutating func reset() {
        tracker.reset()
        startDate = nil
    }
}
