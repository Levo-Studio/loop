import Foundation

// MARK: - Tone

/// A cue written as notes, and the arithmetic that turns it into samples.
///
/// Loop synthesises its tones rather than shipping or borrowing them. That is
/// not a preference — it is what is left once the silent switch has to be
/// ignored.
///
/// The full argument is in `LoopSounds`, and the short version is that it turns
/// on what is *documented* rather than on what was measured. Apple commits to
/// the `.playback` category continuing to sound with the Silent switch set to
/// silent. Apple commits to nothing either way about
/// `AudioServicesPlaySystemSound`, which is what this layer used first — that
/// path may well be audible on a muted phone, but nobody can promise it, and it
/// was not verified here because the Simulator has no Ring/Silent switch to
/// set. A requirement cannot rest on undocumented behaviour, so the cue has to
/// be real playback, and real playback needs real samples.
///
/// Synthesised rather than bundled, given that: files would mean a licence
/// question and three assets to keep in tune with each other, while three sine
/// figures are forty lines of arithmetic, weigh nothing, and can be tested.
///
/// Pure `Foundation` and `nonisolated` on purpose. Synthesis is the part that
/// can be wrong — a phase discontinuity, an envelope that clicks, a figure that
/// no longer rises — and it is testable here in milliseconds, without an audio
/// device, a session or a simulator. `LoopSounds` keeps only the parts that
/// need hardware.
nonisolated struct LoopTone: Sendable, Equatable {

    // MARK: - Notes

    /// One note: a frequency, when it starts, and how long it sounds. Notes are
    /// laid out on the cue's own timeline, so a figure is written the way it is
    /// heard rather than as a chain of offsets.
    struct Note: Sendable, Equatable {
        let frequency: Double
        let start: TimeInterval
        let duration: TimeInterval

        var end: TimeInterval { start + duration }
    }

    let notes: [Note]

    /// How long the whole cue runs. Read by the queue that keeps two cues from
    /// overlapping, and by the timer that drops the audio session afterwards.
    var duration: TimeInterval { notes.map(\.end).max() ?? 0 }

    // MARK: - Pitches

    /// The four pitches the three cues are built from, in equal temperament at
    /// A4 = 440. Named rather than written as numbers at the call site: the
    /// figures are meant to be read as music, because that is what makes them
    /// distinguishable, and `1174.66` on its own says nothing.
    private static let a5 = 880.0
    private static let d6 = 1_174.66
    private static let fSharp6 = 1_479.98
    private static let a6 = 1_760.0

    // MARK: - The three cues

    /// A block ended: two notes, A5 then D6, rising. The ear hears a *figure* —
    /// two events, going up.
    static let blockEnded = LoopTone(notes: [
        Note(frequency: a5, start: 0, duration: 0.18),
        Note(frequency: d6, start: 0.18, duration: 0.24),
    ])

    /// A block began: one plain note at D6, the pitch the pair above lands on.
    /// A *single* event against the other's two, so the two are told apart by
    /// shape rather than by remembering which was higher.
    static let blockBegan = LoopTone(notes: [
        Note(frequency: d6, start: 0, duration: 0.30),
    ])

    /// A timer finished: a D major arpeggio with the root held at the end.
    /// Four times longer than either boundary cue and the only one that is
    /// melodic, so length alone identifies it from the next room.
    static let timerFinished = LoopTone(notes: [
        Note(frequency: d6, start: 0, duration: 0.26),
        Note(frequency: fSharp6, start: 0.28, duration: 0.26),
        Note(frequency: a6, start: 0.56, duration: 0.26),
        Note(frequency: d6, start: 0.84, duration: 0.91),
    ])

    // MARK: - Synthesis

    /// Peak amplitude of a single note.
    ///
    /// Well below full scale. The session ducks the user's music while a cue
    /// plays, so the cue does not also have to be loud to be heard, and a beep
    /// at full scale on headphones is the kind of thing people uninstall an app
    /// over.
    private static let amplitude: Float = 0.32

    /// Attack and release of the envelope, in seconds.
    ///
    /// A note that starts and stops at full amplitude is a step in the
    /// waveform, and a step is a click — audible, cheap-sounding, and blamed on
    /// the speaker rather than on the code. The release is the longer of the
    /// two because a slow decay reads as a bell while a slow attack just reads
    /// as late.
    private static let attack = 0.006
    private static let release = 0.05

    /// The cue rendered as mono samples at `sampleRate`.
    ///
    /// Notes are summed rather than concatenated, so a figure whose notes are
    /// written to overlap renders as a chord rather than clipping one against
    /// the other. That has a ceiling, and it is worth knowing before someone
    /// writes a fourth cue: at this amplitude **three simultaneous notes are
    /// the most that stay inside full scale**, and a fourth peaks at 1.28 and
    /// clips. All three cues today are strictly sequential, so none is near it.
    ///
    /// The guard comes before the conversion rather than after it because
    /// `Int(_:)` traps on a non-finite `Double` — an infinite or NaN sample
    /// rate would take the process down one line before a check placed
    /// underneath it could refuse the input.
    func samples(sampleRate: Double) -> [Float] {
        guard sampleRate > 0, sampleRate.isFinite, duration > 0, duration.isFinite else {
            return []
        }

        let count = Int((duration * sampleRate).rounded(.up))
        guard count > 0 else { return [] }

        var samples = [Float](repeating: 0, count: count)

        for note in notes {
            let first = Int(note.start * sampleRate)
            let last = min(Int(note.end * sampleRate), count)
            guard last > first else { continue }

            // Phase is computed per note from its own start rather than
            // accumulated across the buffer, so every note begins at a zero
            // crossing and the envelope has nothing to fight. Computing also
            // cannot drift the way a running sum of a rounded increment does.
            let step = 2 * Double.pi * note.frequency / sampleRate

            for index in first..<last {
                let elapsed = Double(index - first) / sampleRate
                let value = sin(step * Double(index - first))
                let shaped = value * Self.envelope(at: elapsed, of: note.duration)
                samples[index] += Float(shaped) * Self.amplitude
            }
        }

        return samples
    }

    /// A raised-cosine fade in and out, 0…1.
    ///
    /// Raised cosine rather than a straight line: a linear ramp still has a
    /// corner at each end, and a corner is a faint click of its own.
    private static func envelope(at elapsed: TimeInterval, of duration: TimeInterval) -> Double {
        // A note shorter than its own fades gets a single smooth arc instead,
        // so nothing can produce a negative or overlapping ramp.
        guard duration > attack + release else {
            return 0.5 - 0.5 * cos(2 * .pi * min(max(elapsed / duration, 0), 1))
        }

        if elapsed < attack {
            return 0.5 - 0.5 * cos(.pi * elapsed / attack)
        }

        let remaining = duration - elapsed
        if remaining < release {
            return 0.5 - 0.5 * cos(.pi * max(remaining, 0) / release)
        }

        return 1
    }
}
