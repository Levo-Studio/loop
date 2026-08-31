import SwiftUI

// MARK: - Slide to stop

/// The control that dismisses a ringing countdown: a track the width of a
/// control row, a knob at its left end, and the instruction reading through the
/// middle until the knob arrives.
///
/// **Why a track and not a gesture on the page.** The finished countdown used
/// to accept a vertical drag anywhere on the screen, with the words appended to
/// the line under the time. That is a gesture nobody can see, in the one state
/// where the app is demanding attention from someone who is not looking at it,
/// and its only affordance was a sentence. A control that is drawn is a control
/// that can be found, and a deliberate slide is what keeps an alarm from being
/// dismissed by the palm that picked the phone up.
///
/// **Why it looks like this.** The export draws no such control, so it is built
/// out of parts the app already has rather than invented beside them. The
/// control row is the vocabulary: the track is a secondary button's outline —
/// a full-round capsule in `hairStrong` at the hairline width — and the knob is
/// a primary button's fill, `chipStrong`, because the knob is the part that is
/// acted on. Its label is the button role, 12 pt uppercase at `.12em`. The
/// height is not asserted anywhere: the label carries the control row's own
/// vertical padding, so the track comes out exactly as tall as the buttons it
/// replaces and the finished state does not move against the others.
///
/// The knob sits in the track on the settings toggle's rule — inset by
/// `toggleKnobInset`, with the diameter that leaves — because that is the one
/// knob-in-a-track relationship the design already states, and restating it
/// with a second number would be two answers to one question.
///
/// **The track does not fill in behind the knob.** There is exactly one
/// progress indicator in this app and it is the rising area. A track that
/// coloured in as the knob travelled would be a second one, drawn in the state
/// where the first is at its fullest.
struct SlideToStop: View {

    /// The instruction read through the track.
    let label: LocalizedStringResource

    /// How far the knob has travelled, 0…1.
    ///
    /// A binding, and it has to be. Everything in `PageScaffold`'s slots is
    /// built twice for the two-tone edge, and a finished countdown has a
    /// **full** area — so both copies are drawn, unlike the sliders, whose
    /// second copy is masked away on a page that has no fill. State declared in
    /// here would exist twice, only one copy takes touches, and the knob the
    /// user can see would be the one that never moved. The screen owns the
    /// value; both copies read it.
    @Binding var progress: Double

    /// Run once, when the knob reaches the far end.
    let onComplete: () -> Void

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopInk) private var ink
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(label)
            .loopTextStyle(typography.button)
            .foregroundStyle(ink.base)
            // The knob passes over the words, so the words get out of its way.
            // Fading rather than sliding: the instruction is answered by the
            // gesture that hides it, and an instruction that moved would be a
            // second thing travelling across the track.
            .opacity(1 - progress)
            .frame(maxWidth: .infinity)
            .padding(.vertical, metrics.buttonVerticalPadding)
            .background(Capsule().strokeBorder(ink.hairStrong, lineWidth: metrics.hairlineWidth))
            // The knob is laid over the track rather than inside it, so the
            // label sets the height and the knob is measured from what came
            // out — one geometry, and no height written down twice.
            .overlay { GeometryReader { proxy in knob(in: proxy.size) } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
            .accessibilityAddTraits(.isButton)
            // A drag the length of a control row is not reachable through
            // VoiceOver or Switch Control, and this is the only way out of the
            // state. Activating the element does what arriving at the end does.
            .accessibilityAction(.default) { complete() }
    }

    // MARK: - The knob

    @ViewBuilder private func knob(in size: CGSize) -> some View {
        let inset = metrics.toggleKnobInset
        let diameter = max(0, size.height - 2 * inset)
        let travel = max(0, size.width - diameter - 2 * inset)

        ZStack(alignment: .topLeading) {
            // Holds the overlay open across the whole track, so the drag can
            // begin anywhere on it. A one-knob target is a target the thumb
            // has to find before it can start moving.
            Color.clear

            Capsule()
                .fill(ink.chipStrong)
                .frame(width: diameter, height: diameter)
                .position(x: inset + diameter / 2 + travel * progress, y: size.height / 2)
        }
        .contentShape(.capsule)
        .gesture(drag(travel: travel))
    }

    // MARK: - Dragging

    /// The slide itself.
    ///
    /// Measured from where the finger started rather than from where it is, so
    /// the knob follows the hand by the distance it moved wherever on the track
    /// it was picked up. Every drag starts the knob from rest, which is what a
    /// control that springs back is: a partial slide is not a partial answer
    /// being kept, it is an answer that was not given.
    private func drag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard travel > 0 else { return }

                let moved = min(1, max(0, Double(gesture.translation.width / travel)))
                // The end of the track is the whole test, and it is deliberately
                // the end rather than a fraction of it. A threshold would be a
                // drawn distance the design has no value for, and a dismissal
                // that completes early is one an alarm should not offer.
                let arrived = moved >= 1 && progress < 1
                progress = moved

                if arrived { complete() }
            }
            .onEnded { _ in
                guard progress < 1 else { return }

                // `settle` rather than `selection`: this is the curve for a
                // control coming to rest after the finger has left it, and the
                // knob can be most of a row away from home.
                withAnimation(LoopMotion.resolve(LoopMotion.settle, reduceMotion: reduceMotion)) {
                    progress = 0
                }
            }
    }

    /// Fired from the gesture rather than from a modifier watching `progress`:
    /// this view is built twice inside `FillSurface`, so anything watching the
    /// value would fire from both copies — a doubled haptic and, worse, a
    /// dismissal run twice.
    private func complete() {
        LoopHaptics.detent()
        onComplete()
    }
}

// MARK: - Preview

#Preview {
    SlideToStop(label: LoopStrings.slideToStop, progress: .constant(0)) {}
        .padding()
}
