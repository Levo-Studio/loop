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

    // MARK: - Snapshot

    /// Every part of a frame that depends on *when* it is read, taken at a
    /// single instant and off a single build of the schedule.
    ///
    /// Asking for the phase, then the block, then the time, then the fraction
    /// is four different `now` values and four walks of the schedule. Two of
    /// those instants either side of a block boundary put a "Focus" pill above
    /// a fraction that belongs to the break, and the flicker gets blamed on the
    /// view.
    ///
    /// What is *not* here is what does not move with time: the setup screen's
    /// sum is `plannedDuration`, and the large number on the finished screen is
    /// `focusedDuration`. Both are properties of the timer, and neither is
    /// `blockDuration` — reaching for the snapshot there would print one focus
    /// block, 25:00, where the total, 1:40, belongs.
    struct Snapshot: Sendable, Equatable {
        let phase: Phase
        let blockKind: BlockKind

        /// 1-based round for the counter, "Round 02 / 04".
        let round: Int
        let rounds: Int

        let remaining: TimeInterval
        let blockDuration: TimeInterval

        /// Height of the rising area, 0…1, for the **current** block.
        let fraction: Double

        /// Whether the skip button is live. Breaks only.
        let canSkip: Bool
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

    /// A run needs something to focus on.
    ///
    /// A zero-minute focus would make the run open on a break — "Break · Round
    /// 01 / 04" before anything has been worked on, and "0:00 hours focused" at
    /// the end. Someone who drags the focus scale to zero has asked for
    /// nothing, not for a session of breaks. A zero-minute break is a different
    /// matter and stays allowed: it means focus blocks back to back.
    var canStart: Bool { focusDuration > 0 }

    // MARK: - Reading

    /// One resolve and one walk of the schedule, which every read goes through.
    ///
    /// Two public read paths would be two copies of "which block is this", and
    /// the copies only have to disagree once.
    private struct Reading {
        let phase: Phase
        let elapsed: TimeInterval

        /// The block the elapsed value sits in. `nil` before a run begins and
        /// once it is over — there is no current block in either case.
        let block: Block?
    }

    private func reading(at now: Date) -> Reading {
        let resolved = resolved(at: now)

        switch resolved.storedPhase {
        case .setup:
            return Reading(phase: .setup, elapsed: 0, block: nil)

        case .running, .paused:
            let elapsed = resolved.tracker.elapsed(at: now)

            // A record whose elapsed already sits past the schedule — a store
            // written by an older build, or one edited by hand — reads as
            // finished rather than as a running run with no block.
            guard let block = resolved.block(atElapsed: elapsed) else {
                return Reading(phase: .finished, elapsed: elapsed, block: nil)
            }
            return Reading(phase: resolved.storedPhase, elapsed: elapsed, block: block)

        case .finished:
            return Reading(phase: .finished, elapsed: resolved.plannedDuration, block: nil)
        }
    }

    /// The whole time-dependent state at one instant. This is what a screen
    /// draws from; the accessors below are conveniences for a single value.
    func snapshot(at now: Date) -> Snapshot {
        snapshot(from: reading(at: now))
    }

    private func snapshot(from reading: Reading) -> Snapshot {
        guard let block = reading.block else {
            // Nothing is running. Before a run that means no area at all — a
            // filled screen under a timer that has not been started reads as a
            // design choice rather than as the bug it is — and after one it
            // means the last focus block, full, which is what "Done · 4 of 4"
            // is drawn over.
            let isSetup = reading.phase == .setup

            return Snapshot(
                phase: reading.phase,
                blockKind: .focus,
                round: isSetup ? 1 : rounds,
                rounds: rounds,
                remaining: isSetup ? focusDuration : 0,
                blockDuration: focusDuration,
                fraction: isSetup ? 0 : 1,
                canSkip: false
            )
        }

        let remaining = min(max(0, block.end - reading.elapsed), block.duration)

        return Snapshot(
            phase: reading.phase,
            blockKind: block.kind,
            round: block.round,
            rounds: rounds,
            remaining: remaining,
            blockDuration: block.duration,
            fraction: block.duration > 0 ? 1 - remaining / block.duration : 1,
            canSkip: reading.phase == .running && block.kind == .break
        )
    }

    func phase(at now: Date) -> Phase { snapshot(at: now).phase }

    func remaining(at now: Date) -> TimeInterval { snapshot(at: now).remaining }

    func fraction(at now: Date) -> Double { snapshot(at: now).fraction }

    /// Skip exists for a break only. During focus the design draws the button
    /// disabled, and the engine refuses the call as well — a screen that got it
    /// wrong must not be able to shorten a focus block.
    func canSkip(at now: Date) -> Bool { snapshot(at: now).canSkip }

    /// The block the run is in, or `nil` once it is over or before it begins.
    func currentBlock(at now: Date) -> Block? { reading(at: now).block }

    // MARK: - Resolving

    func resolved(at now: Date) -> IntervalTimer {
        guard storedPhase == .running, tracker.elapsed(at: now) >= plannedDuration else { return self }

        var resolved = self
        resolved.storedPhase = .finished
        resolved.tracker.set(elapsed: plannedDuration, at: now)
        resolved.tracker.pause(at: now)
        return resolved
    }

    mutating func commitTransitions(at now: Date) { self = resolved(at: now) }

    // MARK: - Setup

    @discardableResult
    mutating func setFocusMinutes(_ minutes: Int, at now: Date) -> Bool {
        commitTransitions(at: now)
        guard storedPhase == .setup else { return false }
        focusMinutes = LoopTimerLimits.clamp(minutes, to: LoopTimerLimits.durationMinutes)
        return true
    }

    @discardableResult
    mutating func setBreakMinutes(_ minutes: Int, at now: Date) -> Bool {
        commitTransitions(at: now)
        guard storedPhase == .setup else { return false }
        breakMinutes = LoopTimerLimits.clamp(minutes, to: LoopTimerLimits.breakMinutes)
        return true
    }

    @discardableResult
    mutating func setRounds(_ count: Int, at now: Date) -> Bool {
        commitTransitions(at: now)
        guard storedPhase == .setup else { return false }
        rounds = LoopTimerLimits.clamp(count, to: LoopTimerLimits.rounds)
        return true
    }

    // MARK: - Running

    @discardableResult
    mutating func start(at now: Date) -> Bool {
        commitTransitions(at: now)
        guard canStart, storedPhase == .setup || storedPhase == .finished else { return false }
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

    /// Jumps to the next focus block. Legal during a break and nowhere else.
    @discardableResult
    mutating func skip(at now: Date) -> Bool {
        commitTransitions(at: now)

        let reading = reading(at: now)
        guard snapshot(from: reading).canSkip, let block = reading.block else { return false }

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

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case focusMinutes
        case breakMinutes
        case rounds
        case storedPhase
        case tracker
    }

    /// Written out rather than synthesised. A synthesised `init(from:)` skips
    /// the clamps above, and a stored `rounds` of zero would then reach
    /// `1...rounds` in `schedule` and trap on the launch path — a corrupted
    /// store has to stay loadable, which is the whole point of clamping rather
    /// than trapping.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = LoopTimerLimits.clamp(
            try container.decode(Int.self, forKey: .focusMinutes),
            to: LoopTimerLimits.durationMinutes
        )
        breakMinutes = LoopTimerLimits.clamp(
            try container.decode(Int.self, forKey: .breakMinutes),
            to: LoopTimerLimits.breakMinutes
        )
        rounds = LoopTimerLimits.clamp(
            try container.decode(Int.self, forKey: .rounds),
            to: LoopTimerLimits.rounds
        )
        storedPhase = try container.decode(Phase.self, forKey: .storedPhase)
        tracker = try container.decode(ElapsedTracker.self, forKey: .tracker)
    }
}
