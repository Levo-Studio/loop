import Testing

@testable import Loop

// MARK: - Detent feedback

/// The tap rule, on its own.
///
/// It used to be a side effect of the comparison that decided whether to write
/// the value at all, where nothing could reach it. It is the half of that
/// comparison worth keeping — a drag reports many times per detent, so without
/// a rule the scale buzzes — and these hold it to "once per detent landed on".
@Suite("Detent feedback")
struct DetentFeedbackTests {

    /// The detents a run of gesture callbacks taps on, in order.
    private func taps(from start: Int, over detents: [Int]) -> [Int] {
        var feedback = DetentFeedback()
        feedback.begin(at: start)
        return detents.filter { feedback.arrived(at: $0) }
    }

    @Test("Putting a finger down without moving it is silent")
    func touchDownIsSilent() {
        #expect(taps(from: 25, over: [25, 25, 25]).isEmpty)
    }

    @Test("A drag taps once per detent, not once per callback")
    func oncePerDetent() {
        // The pitch is several points per minute, so several callbacks pass
        // while the marker is still over the same one.
        #expect(taps(from: 25, over: [25, 26, 26, 26, 27, 27]) == [26, 27])
    }

    @Test("Coming back to a detent is arriving at it again")
    func returningTaps() {
        // The value the finger stops on is a choice however it was reached,
        // and this is the case the old comparison could not see: it asked the
        // binding, which was still reading 25.
        #expect(taps(from: 25, over: [26, 25]) == [26, 25])
    }

    @Test("A new gesture starts silent wherever the last one ended")
    func gesturesDoNotCarryOver() {
        var feedback = DetentFeedback()
        feedback.begin(at: 25)
        let onTheWay = feedback.arrived(at: 40)

        // A finger put down mid-settle takes the scale over from where it is
        // drawn, and taking it over is not a detent landed on.
        feedback.begin(at: 40)
        let takingOver = feedback.arrived(at: 40)
        let afterwards = feedback.arrived(at: 45)

        #expect(onTheWay)
        #expect(takingOver == false)
        #expect(afterwards)
    }
}
