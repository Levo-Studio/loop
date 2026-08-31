import Foundation

// MARK: - Elapsed tracker

/// How long something has been running, expressed as an instant plus the time
/// banked before it.
///
/// This is the one place in the engine that touches wall time, and all three
/// timers are built on it. Nothing counts ticks: while the tracker runs it
/// holds the `Date` it was started at, so the elapsed value is a subtraction,
/// not an accumulation. That is what makes a run survive a restart, a locked
/// screen and two hours in the background — the instant survives, and the
/// subtraction gives the same answer afterwards as it would have given all
/// along.
///
/// Pausing banks the running span into `accumulated` and drops the instant, so
/// a resume continues from where the freeze happened rather than from where
/// wall time got to in the meantime.
nonisolated struct ElapsedTracker: Sendable, Codable, Equatable {

    // MARK: - Storage

    /// Time banked by earlier, already finished running spans.
    private(set) var accumulated: TimeInterval

    /// The instant the current span began, or `nil` while not running.
    private(set) var startedAt: Date?

    var isRunning: Bool { startedAt != nil }

    // MARK: - Life cycle

    init(accumulated: TimeInterval = 0, startedAt: Date? = nil) {
        self.accumulated = max(0, accumulated)
        self.startedAt = startedAt
    }

    // MARK: - Reading

    func elapsed(at now: Date) -> TimeInterval {
        guard let startedAt else { return accumulated }

        // A negative span is possible: the user can move the system clock
        // backwards, and a restored state can be newer than the `now` a caller
        // hands in. Treating that as zero freezes the timer for the duration of
        // the jump, which is dull and safe; letting it through would run the
        // timer backwards through its own block boundaries.
        return accumulated + max(0, now.timeIntervalSince(startedAt))
    }

    // MARK: - Writing

    mutating func start(at now: Date) {
        guard startedAt == nil else { return }
        startedAt = now
    }

    mutating func pause(at now: Date) {
        accumulated = elapsed(at: now)
        startedAt = nil
    }

    /// Moves the elapsed value without stopping. Used by the interval's skip,
    /// which jumps to a block boundary and keeps running from there.
    mutating func set(elapsed: TimeInterval, at now: Date) {
        accumulated = max(0, elapsed)
        if startedAt != nil { startedAt = now }
    }

    mutating func reset() {
        accumulated = 0
        startedAt = nil
    }

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case accumulated
        case startedAt
    }

    /// Written out rather than synthesised, because a synthesised
    /// `init(from:)` assigns the stored properties directly and would let a
    /// negative span in from a damaged record — the one path into this type
    /// that does not go through the initialiser above.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accumulated = max(0, try container.decode(TimeInterval.self, forKey: .accumulated))
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
    }
}
