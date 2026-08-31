import Foundation

// MARK: - Interval

/// Focus and break blocks over a number of rounds.
///
/// The whole run is one schedule laid out on a single elapsed value: focus,
/// break, focus, break … and a last focus block with **no break after it**. A
/// block change is therefore not an event that has to fire on time — it is the
/// position of the elapsed value in that schedule. That is the reason an
/// interval left running overnight comes back on the right block, or finished,
/// without anything having stayed awake.
nonisolated struct IntervalTimer: Sendable, Codable, Equatable {

    // MARK: - Phase and block

    enum Phase: String, Sendable, Codable, CaseIterable {
        case setup
        case running
        case paused
        case finished
    }

    enum BlockKind: String, Sendable, Codable, CaseIterable {
        case focus
        case `break`
    }

    /// One entry of the schedule, with the offset it begins at.
    struct Block: Sendable, Equatable {
        let kind: BlockKind
        /// 1-based, as shown in "Focus · Round 02 / 04".
        let round: Int
        let duration: TimeInterval
        let start: TimeInterval

        var end: TimeInterval { start + duration }
    }

    // MARK: - Storage

    private(set) var focusMinutes: Int
    private(set) var breakMinutes: Int
    private(set) var rounds: Int

    private var storedPhase: Phase
    private var tracker: ElapsedTracker

    // MARK: - Life cycle

    /// The values the setup screen is drawn with.
    init(focusMinutes: Int = 25, breakMinutes: Int = 5, rounds: Int = 4) {
        self.focusMinutes = LoopTimerLimits.clamp(focusMinutes, to: LoopTimerLimits.durationMinutes)
        self.breakMinutes = LoopTimerLimits.clamp(breakMinutes, to: LoopTimerLimits.breakMinutes)
        self.rounds = LoopTimerLimits.clamp(rounds, to: LoopTimerLimits.rounds)
        storedPhase = .setup
        tracker = ElapsedTracker()
    }

    // MARK: - Schedule

    /// Focus, break, focus, break … and no break after the final round.
    var schedule: [Block] {
        var blocks: [Block] = []
        var offset: TimeInterval = 0

        for round in 1...rounds {
            blocks.append(Block(kind: .focus, round: round, duration: focusDuration, start: offset))
            offset += focusDuration

            guard round < rounds else { break }

            blocks.append(Block(kind: .break, round: round, duration: breakDuration, start: offset))
            offset += breakDuration
        }

        return blocks
    }

    var focusDuration: TimeInterval { TimeInterval(focusMinutes) * 60 }
    var breakDuration: TimeInterval { TimeInterval(breakMinutes) * 60 }

    /// The wall time a full run takes. The last round has no break, so this is
    /// not `rounds × (focus + break)`.
    var plannedDuration: TimeInterval {
        TimeInterval(rounds) * focusDuration + TimeInterval(rounds - 1) * breakDuration
    }

    /// What the finished screen reports as time focused: the focus blocks only.
    var focusedDuration: TimeInterval { TimeInterval(rounds) * focusDuration }

    /// A run with nothing in it cannot be started. With both scales at zero
    /// every block is empty and the run would finish in the frame it started,
    /// so the start button stays disabled instead. A single zero scale is fine:
    /// an empty block is simply passed through, which is what "0 min break"
    /// should mean.
    var canStart: Bool { plannedDuration > 0 }

    // MARK: - Reading

    func phase(at now: Date) -> Phase { settled(at: now).storedPhase }

    /// The block the run is in, or `nil` once it is over.
    func currentBlock(at now: Date) -> Block? {
        let settled = settled(at: now)
        guard settled.storedPhase == .running || settled.storedPhase == .paused else { return nil }
        return settled.block(atElapsed: settled.tracker.elapsed(at: now))
    }

    /// The block for the pill and the round counter. A finished run keeps
    /// reporting the last focus block, because "Done · 4 of 4" is drawn with the
    /// round count, not with a blank; a run still in setup reports the block it
    /// will begin with.
    func displayedBlock(at now: Date) -> Block {
        if let block = currentBlock(at: now) { return block }
        let blocks = schedule
        return phase(at: now) == .setup ? blocks[0] : blocks[blocks.count - 1]
    }

    func remaining(at now: Date) -> TimeInterval {
        guard let block = currentBlock(at: now) else { return 0 }
        let elapsed = settled(at: now).tracker.elapsed(at: now)
        return min(max(0, block.end - elapsed), block.duration)
    }

    /// 1 − remaining / duration of the **current** block, so it drops back to
    /// zero the moment the schedule moves on.
    func fraction(at now: Date) -> Double {
        guard let block = currentBlock(at: now) else { return 1 }
        guard block.duration > 0 else { return 1 }
        return 1 - remaining(at: now) / block.duration
    }

    /// Skip exists for a break only. During focus the design draws the button
    /// disabled, and the engine refuses the call as well — a screen that got it
    /// wrong must not be able to shorten a focus block.
    func canSkip(at now: Date) -> Bool {
        let settled = settled(at: now)
        guard settled.storedPhase == .running else { return false }
        return settled.currentBlock(at: now)?.kind == .break
    }

    // MARK: - Settling

    func settled(at now: Date) -> IntervalTimer {
        guard storedPhase == .running, tracker.elapsed(at: now) >= plannedDuration else { return self }

        var settled = self
        settled.storedPhase = .finished
        settled.tracker.set(elapsed: plannedDuration, at: now)
        settled.tracker.pause(at: now)
        return settled
    }

    mutating func settle(at now: Date) { self = settled(at: now) }

    // MARK: - Setup

    @discardableResult
    mutating func setFocusMinutes(_ minutes: Int, at now: Date) -> Bool {
        settle(at: now)
        guard storedPhase == .setup else { return false }
        focusMinutes = LoopTimerLimits.clamp(minutes, to: LoopTimerLimits.durationMinutes)
        return true
    }

    @discardableResult
    mutating func setBreakMinutes(_ minutes: Int, at now: Date) -> Bool {
        settle(at: now)
        guard storedPhase == .setup else { return false }
        breakMinutes = LoopTimerLimits.clamp(minutes, to: LoopTimerLimits.breakMinutes)
        return true
    }

    @discardableResult
    mutating func setRounds(_ count: Int, at now: Date) -> Bool {
        settle(at: now)
        guard storedPhase == .setup else { return false }
        rounds = LoopTimerLimits.clamp(count, to: LoopTimerLimits.rounds)
        return true
    }

    // MARK: - Running

    @discardableResult
    mutating func start(at now: Date) -> Bool {
        settle(at: now)
        guard canStart, storedPhase == .setup || storedPhase == .finished else { return false }
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

    /// Jumps to the next focus block. Legal during a break and nowhere else.
    @discardableResult
    mutating func skip(at now: Date) -> Bool {
        settle(at: now)
        guard canSkip(at: now), let block = currentBlock(at: now) else { return false }

        // Landing exactly on the boundary puts the run at the start of the next
        // block, which is the focus block that follows every break.
        tracker.set(elapsed: block.end, at: now)
        return true
    }

    /// Back to the setup screen with the scales untouched.
    mutating func reset() {
        tracker.reset()
        storedPhase = .setup
    }

    // MARK: - Schedule lookup

    /// The first block that has not ended yet. A zero-length block ends where it
    /// starts, so it is stepped over here instead of being shown for a frame.
    private func block(atElapsed elapsed: TimeInterval) -> Block? {
        schedule.first { $0.end > elapsed }
    }
}
