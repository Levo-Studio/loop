import Testing

@testable import Loop

// MARK: - Sounds

/// Nothing here listens to anything. What a test can hold is that the three
/// cues are three *different* sounds and that the lengths the queue relies on
/// were not left at a placeholder — both of which are the mistakes that produce
/// a feature that appears to work and tells you nothing.
@Suite("Sounds")
struct LoopSoundsTests {

    @Test("Every cue plays a different sound")
    func distinctIdentifiers() {
        // The point of the pair is being told apart, so two cues sharing an
        // identifier is the failure the whole feature is built to avoid — and
        // it is a one-character typo away at all times.
        let identifiers = LoopSounds.Cue.allCases.map(\.identifier)
        #expect(Set(identifiers).count == LoopSounds.Cue.allCases.count)
    }

    @Test("Every cue knows how long it runs")
    func lengths() {
        // The queue that keeps two cues from overlapping has nothing else to
        // go on: `AudioServicesPlaySystemSound` never reports finishing.
        for cue in LoopSounds.Cue.allCases {
            #expect(cue.length > 0)
        }

        // The finish is the long one on purpose — length is what separates it
        // from the two boundary tones, so it has to stay clearly longer than
        // both rather than drifting into the same range.
        #expect(LoopSounds.Cue.timerFinished.length > 2 * LoopSounds.Cue.blockEnded.length)
        #expect(LoopSounds.Cue.timerFinished.length > 2 * LoopSounds.Cue.blockBegan.length)
    }
}
