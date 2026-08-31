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

    /// Everything the count-up screen draws, read at a single instant — the
    /// same shape the other two timers offer, so all three screens are written
    /// the same way.
    ///
    /// Nothing is deliberately left off here. The page has no scale, no total
    /// and no round counter; its three states differ only in the phase, and
    /// which of Start, Pause, Resume and Reset is live follows from that alone,
    /// so there is no `canStart` to carry.
    struct Snapshot: Sendable, Equatable {
        let phase: Phase
        let elapsed: TimeInterval

        /// The instant the run began, for the "since 09:29" line. `nil` while
        /// idle.
        ///
        /// The optionality is wider than the states the engine can produce:
        /// `running` and `paused` always have an instant — `start(at:)` sets
        /// one and decoding repairs a record that lost it — so only `idle` is
        /// ever `nil`. A screen still has to write a branch for a combination
        /// that cannot happen.
        ///
        /// The shape that would say so is a payload on the phase,
        /// `case running(since: Date)`, or an accessor only the running case
        /// can reach, picked once for all three snapshots rather than for this
        /// one. It is deferred, not missed: the phase is what every screen
        /// switches on, and churning five of them again costs more than one
        /// guarded `nil` that is currently honest. Whoever adds the sixth
        /// screen should reopen it.
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

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case tracker
        case startDate
    }

    /// There are no bounds to clamp here, unlike the other two timers, but
    /// there is a combination the type cannot describe: a tracker that is
    /// running or holds time while `startDate` is `nil`. The phase would read
    /// as running with nothing for the "since 09:29" line to name.
    ///
    /// A run is defined by the instant it began. If the tracker still has that
    /// instant, it is the run's; if nothing anywhere has one, there is no run
    /// to describe and the page starts at zero rather than showing time it
    /// cannot account for.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tracker = try container.decode(ElapsedTracker.self, forKey: .tracker)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)

        guard startDate == nil else { return }

        if let startedAt = tracker.startedAt {
            startDate = startedAt
        } else {
            tracker.reset()
        }
    }
}
