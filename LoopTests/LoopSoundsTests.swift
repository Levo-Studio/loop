import Foundation
import Testing

@testable import Loop

// MARK: - Sounds

/// Nothing here listens to anything, and it does not have to. Loop synthesises
/// its cues, so everything that can be wrong about them is arithmetic:
/// the figures being distinguishable, the envelope not clicking, the samples
/// staying inside full scale. All of it is testable without an audio device.
@Suite("Sounds")
struct LoopSoundsTests {

    private let rate = 44_100.0

    // MARK: - The three figures

    @Test("Every cue is a different figure")
    func distinctTones() {
        // The point of the pair is being told apart, so two cues resolving to
        // the same figure is the failure the whole feature is built to avoid —
        // and it is one copied line away at all times.
        let tones = LoopSounds.Cue.allCases.map(\.tone)
        for (index, tone) in tones.enumerated() {
            for other in tones[(index + 1)...] {
                #expect(tone != other)
            }
        }
    }

    @Test("The boundary pair differs in shape, not just in pitch")
    func theBoundaryPairIsToldApartByShape() {
        // Two notes against one. Someone who cannot recall which was higher
        // can still count events, which is what "without looking" means.
        #expect(LoopTone.blockEnded.notes.count == 2)
        #expect(LoopTone.blockBegan.notes.count == 1)

        // And the pair rises, so the figure has a direction rather than being
        // two arbitrary pitches.
        let ended = LoopTone.blockEnded.notes
        #expect(ended[1].frequency > ended[0].frequency)

        // The single note sits at the pitch the pair lands on: the two cues
        // share an anchor, which is what makes them a pair rather than two
        // unrelated beeps.
        #expect(LoopTone.blockBegan.notes[0].frequency == ended[1].frequency)
    }

    @Test("The finish is the long one, by a wide margin")
    func theFinishIsUnmistakablyLonger() {
        // Length is what identifies the finish from the next room, so it has to
        // stay clearly longer than both boundary cues rather than drifting into
        // the same range.
        #expect(LoopTone.timerFinished.duration > 3 * LoopTone.blockEnded.duration)
        #expect(LoopTone.timerFinished.duration > 3 * LoopTone.blockBegan.duration)
    }

    @Test("A cue's duration is the end of its last note")
    func duration() {
        let tone = LoopTone(notes: [
            .init(frequency: 440, start: 0, duration: 0.1),
            .init(frequency: 880, start: 0.5, duration: 0.25),
        ])
        #expect(tone.duration == 0.75)

        // Not the sum of the notes, and not the end of whichever note happens
        // to be written last.
        let unordered = LoopTone(notes: [
            .init(frequency: 880, start: 0.5, duration: 0.25),
            .init(frequency: 440, start: 0, duration: 0.1),
        ])
        #expect(unordered.duration == 0.75)
    }

    // MARK: - Synthesis

    @Test("Every cue renders the samples its duration promises")
    func sampleCount() {
        for cue in LoopSounds.Cue.allCases {
            let samples = cue.tone.samples(sampleRate: rate)
            #expect(samples.count == Int((cue.tone.duration * rate).rounded(.up)))
        }
    }

    @Test("Nothing clips")
    func headroom() {
        // A buffer over full scale does not get louder, it gets distorted, and
        // the distortion is blamed on the speaker.
        for cue in LoopSounds.Cue.allCases {
            let peak = cue.tone.samples(sampleRate: rate).map(abs).max() ?? 0
            #expect(peak > 0, "a silent cue is not a cue")
            #expect(peak < 1)
        }
    }

    @Test("Every note starts and ends at silence")
    func theEnvelopeDoesNotClick() {
        // A note that begins or ends at full amplitude is a step in the
        // waveform, and a step is an audible click. This is the whole reason
        // the envelope exists, so it is the thing worth pinning.
        for cue in LoopSounds.Cue.allCases {
            let samples = cue.tone.samples(sampleRate: rate)
            #expect(abs(samples[0]) < 0.01)
            #expect(abs(samples[samples.count - 1]) < 0.01)
        }
    }

    @Test("A gap between two notes is actually silent")
    func gapsAreSilent() {
        // The finish is an arpeggio with gaps between its notes. If the
        // envelope ever failed to close, the gap would fill with the previous
        // pitch and the figure would smear into one tone.
        let notes = LoopTone.timerFinished.notes
        let gap = (notes[0].end + notes[1].start) / 2
        let samples = LoopTone.timerFinished.samples(sampleRate: rate)

        #expect(notes[1].start > notes[0].end, "this test assumes a gap to look into")
        #expect(abs(samples[Int(gap * rate)]) < 0.01)
    }

    @Test("A cue with no notes renders nothing rather than trapping")
    func emptyTone() {
        #expect(LoopTone(notes: []).duration == 0)
        #expect(LoopTone(notes: []).samples(sampleRate: rate).isEmpty)

        // A nonsense sample rate is a division by zero waiting to happen.
        #expect(LoopTone.blockBegan.samples(sampleRate: 0).isEmpty)
    }

    @Test("The same cue renders the same samples at any supported rate")
    func rateIndependence() {
        // The engine resamples to whatever the hardware wants, so the figure
        // has to be a function of time rather than of the buffer length.
        let low = LoopTone.blockBegan.samples(sampleRate: 22_050)
        let high = LoopTone.blockBegan.samples(sampleRate: 48_000)

        #expect(low.count == Int((LoopTone.blockBegan.duration * 22_050).rounded(.up)))
        #expect(high.count == Int((LoopTone.blockBegan.duration * 48_000).rounded(.up)))

        // Same peak either way: the envelope is in seconds, not in samples.
        let lowPeak = low.map(abs).max() ?? 0
        let highPeak = high.map(abs).max() ?? 0
        #expect(abs(lowPeak - highPeak) < 0.02)
    }
}
