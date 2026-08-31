import Foundation

// MARK: - Persisted state

/// The three timers together, as they are written to disk.
///
/// One record rather than three keys: the pages are swiped between and any of
/// them can be running when the app goes away, so there is no moment at which
/// only one of them is worth saving.
nonisolated struct LoopTimerState: Sendable, Codable, Equatable {

    var countUp: CountUpTimer
    var countdown: CountdownTimer
    var interval: IntervalTimer

    init(
        countUp: CountUpTimer = CountUpTimer(),
        countdown: CountdownTimer = CountdownTimer(),
        interval: IntervalTimer = IntervalTimer()
    ) {
        self.countUp = countUp
        self.countdown = countdown
        self.interval = interval
    }

    /// Applies every time-driven transition that happened while the app was
    /// gone.
    ///
    /// Nothing is subtracted for the time in the background, and that is the
    /// point: a countdown started half an hour ago with 25 minutes on it is
    /// over, and an interval left running overnight has run its whole schedule.
    /// The alternative — pausing on the way out — would mean the timer lies
    /// about a session the user actually spent away from the app.
    func restored(at now: Date) -> LoopTimerState {
        LoopTimerState(
            countUp: countUp,
            countdown: countdown.settled(at: now),
            interval: interval.settled(at: now)
        )
    }
}

// MARK: - Store

/// Reads and writes `LoopTimerState`.
///
/// JSON in `UserDefaults` rather than a file: the record is a few hundred
/// bytes, it is written whenever a timer changes state, and a synchronous
/// read on launch has to be cheap enough not to be noticed.
///
/// Not `Sendable`, unlike everything else in the engine: `UserDefaults` is not,
/// and the store is only ever used from wherever the app's state lives. The
/// values it carries in and out are `Sendable`, which is the part that matters.
nonisolated struct TimerStateStore {

    private let defaults: UserDefaults
    private let key: String

    /// Namespaced, so nothing in the app can collide with a system default.
    init(defaults: UserDefaults = .standard, key: String = "loop.timers.state") {
        self.defaults = defaults
        self.key = key
    }

    /// The stored state, already brought up to `now`.
    ///
    /// A record that cannot be decoded — an older build's shape, a truncated
    /// write — gives fresh timers rather than an error. There is nothing here
    /// worth interrupting a launch for.
    func load(at now: Date) -> LoopTimerState {
        guard
            let data = defaults.data(forKey: key),
            let state = try? JSONDecoder().decode(LoopTimerState.self, from: data)
        else { return LoopTimerState() }

        return state.restored(at: now)
    }

    func save(_ state: LoopTimerState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
