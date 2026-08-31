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

    var phase: Phase {
        if tracker.isRunning { return .running }
        return startDate == nil ? .idle : .paused
    }

    func elapsed(at now: Date) -> TimeInterval {
        tracker.elapsed(at: now)
    }

    // MARK: - Writing

    mutating func start(at now: Date) {
        guard phase != .running else { return }
        if startDate == nil { startDate = now }
        tracker.start(at: now)
    }

    mutating func pause(at now: Date) {
        guard phase == .running else { return }
        tracker.pause(at: now)
    }

    mutating func reset() {
        tracker.reset()
        startDate = nil
    }
}
