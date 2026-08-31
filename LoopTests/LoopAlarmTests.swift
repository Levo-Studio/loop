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
