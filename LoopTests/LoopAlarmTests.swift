import Foundation
import Testing

@testable import Loop

// MARK: - Alarm

/// The cadence of the repeating finish cue.
///
/// Nothing here plays anything, and it does not have to: what can be wrong
/// about an alarm that repeats is its arithmetic — the gap being long enough to
/// be a gap, the schedule not drifting, and a wake after a suspension being
/// dropped rather than beeping for a countdown that ended twenty minutes ago.
/// All of it is pure `Foundation` and reachable without an audio device.
@Suite("Alarm")
struct LoopAlarmTests {

    private let schedule = LoopAlarm.Schedule.finished

    // MARK: - The cadence

    @Test("The alarm repeats the finish cue and nothing else")
    func theAlarmSoundsTheFinishCue() {
        // A boundary cue here would be an interval's message played by a
        // countdown, and the two are told apart by figure on purpose.
        #expect(schedule.cue == .timerFinished)
    }

    @Test("A repetition is one sounding plus its silence")
    func period() {
        #expect(schedule.period == LoopTone.timerFinished.duration + schedule.gap)
    }

    @Test("The silence clears the held note the finish cue ends on")
    func theGapIsLongerThanTheNoteBeforeIt() {
        // The finish is an arpeggio whose last note is held, and that held note
        // is what identifies it. A gap shorter than it means the next sounding
        // begins while the ear is still inside the previous one, which reads as
        // a stutter rather than as an alarm repeating.
        let held = LoopTone.timerFinished.notes.map(\.duration).max() ?? 0
        #expect(held > 0, "this test assumes the finish cue holds a note")
        #expect(schedule.gap > held)
    }

    @Test("A repetition is far enough apart to be an event and close enough to still be asking")
    func theCadenceIsAnAlarmRatherThanAStutterOrASilence() {
        // The two failures sit either side of the choice. Below the cue's own
        // length there is no silence at all; several seconds of nothing reads
        // as the timer having given up, which is the one thing an alarm must
        // never do.
        #expect(schedule.period > LoopTone.timerFinished.duration)
        #expect(schedule.period <= 4)
    }

    // MARK: - The schedule

    @Test("Repetitions are measured from the first, not from the last")
    func theScheduleDoesNotDrift() {
        // Counted from the instant the alarm began, so scheduling slop is
        // absorbed on every wake rather than added to itself — the same reason
        // the screens derive the time from `Date` instead of counting ticks.
        let begun = Date(timeIntervalSinceReferenceDate: 0)

        for repetition in 1...20 {
            let due = schedule.due(repetition: repetition, from: begun)
            #expect(due.timeIntervalSince(begun) == schedule.period * Double(repetition))
        }
    }

    @Test("The first sounding is at the start, so the alarm begins the instant the timer ends")
    func theAlarmStartsImmediately() {
        // Repetition zero is the instant the countdown finished: the loop plays
        // before it waits, so nothing sits silent for a period first.
        let begun = Date(timeIntervalSinceReferenceDate: 0)
        #expect(schedule.due(repetition: 0, from: begun) == begun)
    }

    // MARK: - Giving up

    @Test("The alarm gives up after a quarter of an hour")
    func theLimitIsFifteenMinutes() {
        // Borrowed from the iOS timer rather than chosen here, which is the
        // whole reason it is a specific number: a user who knows the system's
        // alarm knows how long this one lasts without being told.
        #expect(schedule.limit == 15 * 60)
    }

    @Test("Still ringing at fourteen minutes, silent at sixteen")
    func theAlarmRingsForItsLimitAndNoLonger() {
        let begun = Date(timeIntervalSinceReferenceDate: 0)

        // The pair either side of the limit, asked the way the loop asks it:
        // of a sounding's due time, not of a count of soundings.
        #expect(!schedule.isOver(due: begun.addingTimeInterval(14 * 60), from: begun))
        #expect(schedule.isOver(due: begun.addingTimeInterval(16 * 60), from: begun))

        // And exactly on it, which is the boundary a rewrite gets wrong: the
        // sounding due at the limit is the last one that still plays.
        #expect(!schedule.isOver(due: begun.addingTimeInterval(schedule.limit), from: begun))
        #expect(schedule.isOver(due: begun.addingTimeInterval(schedule.limit + 0.01), from: begun))
    }

    @Test("The limit is measured from the start, not counted off the repetitions")
    func theLimitDoesNotDriftWithTheRepetitions() {
        // The failure this guards against is a cap implemented as "give up
        // after N soundings". That is the same thing only while nothing slips;
        // a wake that arrives late would buy the alarm extra ringing, and a
        // long enough run of them would keep a phone sounding well past the
        // quarter of an hour the limit promises.
        let begun = Date(timeIntervalSinceReferenceDate: 0)

        // Walk the schedule and find the last repetition that still sounds.
        //
        // Bounded, and the bound is the point rather than caution: a walk that
        // asked the thing under test when to stop would hang instead of fail
        // against an implementation that never gives up, and a hanging test
        // reports nothing. Twice the repetitions the limit can hold is past
        // any answer that could be right.
        let ceiling = Int((schedule.limit / schedule.period).rounded(.up)) * 2
        var last = 0
        while last < ceiling,
              !schedule.isOver(due: schedule.due(repetition: last + 1, from: begun), from: begun) {
            last += 1
        }
        #expect(last < ceiling, "the alarm never gives up")

        // It lands where the arithmetic says and nowhere else: the alarm stops
        // within one period of its limit, from either side.
        let ended = schedule.due(repetition: last, from: begun).timeIntervalSince(begun)
        #expect(ended <= schedule.limit)
        #expect(ended > schedule.limit - schedule.period)

        // The same question asked at a repetition whose due time was reached
        // late gets the same answer, because the answer never looks at when a
        // wake actually happened.
        let due = schedule.due(repetition: last + 1, from: begun)
        #expect(schedule.isOver(due: due, from: begun))
    }

    @Test("Going quiet is not the same event as being dismissed")
    func theLimitEndsTheSoundAndNothingElse() {
        // `Schedule` decides when to stop asking and knows nothing about the
        // screen — no phase, no control, no dismissal. That is the guarantee
        // the brief actually turns on: a user who comes back twenty minutes
        // late finds the same finished state, silent, with the slide still the
        // way out. If this type ever grew a way to say otherwise, this is the
        // test that should have to be changed to allow it.
        #expect(schedule.isOver(due: Date(timeIntervalSinceReferenceDate: 20 * 60),
                                from: Date(timeIntervalSinceReferenceDate: 0)))
        #expect(LoopDismissal.requiresSwipe(.countdown, swipeToDismissEnabled: true))
    }

    // MARK: - Coming back from a suspension

    @Test("A wake that is merely late still sounds")
    func jitterIsTolerated() {
        let due = Date(timeIntervalSinceReferenceDate: 0)
        #expect(!schedule.isStale(due: due, at: due))
        #expect(!schedule.isStale(due: due, at: due.addingTimeInterval(LoopSounds.lateness)))
    }

    @Test("A wake after a suspension is dropped rather than played")
    func aSuspendedSleepDoesNotResumeTheAlarm() {
        // The case this exists for: iOS suspends Loop seconds after it leaves
        // the screen and the sleep resumes when the app is next opened. Without
        // the drop, a countdown that finished twenty minutes ago starts ringing
        // before anyone has read what the screen says.
        let due = Date(timeIntervalSinceReferenceDate: 0)
        #expect(schedule.isStale(due: due, at: due.addingTimeInterval(LoopSounds.lateness + 0.01)))
        #expect(schedule.isStale(due: due, at: due.addingTimeInterval(20 * 60)))
    }

    @Test("A wake that arrives early is never stale")
    func anEarlyWakeIsNotStale() {
        // Sleeping can return a hair early, and a negative lateness compared
        // against a positive tolerance is the sign error that would silence the
        // alarm on its second sounding.
        let due = Date(timeIntervalSinceReferenceDate: 0)
        #expect(!schedule.isStale(due: due, at: due.addingTimeInterval(-0.2)))
    }
}
