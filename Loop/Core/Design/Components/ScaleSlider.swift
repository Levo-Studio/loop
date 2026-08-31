import SwiftUI

// MARK: - Scale slider

/// The minute scale used to set a duration — the countdown's length, the
/// interval's focus and break blocks.
///
/// It is not a track with a knob. The scale itself is the control: a tick per
/// selectable value, a taller one every five minutes, a number every
/// `numberEvery`, and a bar in the accent marking the value. Reading it tells
/// you the number without the header, which is why the header can stay as quiet
/// as it is.
///
/// **The scale scrolls and the marker does not.** The bar sits fixed at the
/// centre and the scale travels under it, so the value is what is under the
/// centre rather than where the marker has reached along a fixed track. That is
/// what takes the screen width out of the range: a track has to fit its whole
/// range on screen, a scrolling scale does not, and thirty hours will not fit on
/// any phone at the density the export draws. The export shows the inverse and
/// is superseded here; every drawn value it does carry — tick heights and
/// widths, the five-minute major, the number row, the 3 × 30 pt bar, the
/// opacities, the landscape variants — is unchanged.
struct ScaleSlider: View {

    let label: LocalizedStringResource

    @Binding var minutes: Int

    /// How far the scale runs and which values on it can be stopped on.
    ///
    /// Handed in by the screen rather than decided here. Which durations are
    /// selectable is a rule about the timer — one-minute steps to two hours,
    /// five-minute steps beyond — and rules about the timer live in
    /// `Loop/Engine/`, where a test can reach them without a simulator.
    let minuteScale: LoopMinuteScale

    /// How often a number is printed under the scale, in minutes.
    ///
    /// Comes from `LoopMetrics.countdownNumberInterval`,
    /// `.focusNumberInterval` or `.breakNumberInterval`. Deliberately has no
    /// default: a wrong-but-plausible density is the kind of thing that
    /// survives review, so each scale has to say which of the three it is.
    let numberEvery: Int

    /// The unit after the header's value **while it is under an hour** — " min"
    /// on every scale in the app.
    ///
    /// Only half the answer, because only half of it is the caller's to choose.
    /// The header switches to `h:mm` at an hour, and the unit that goes with
    /// that format goes with the format rather than with the screen: a call
    /// site that could pair "2:05" with " min" is a call site that eventually
    /// does.
    let unit: LocalizedStringResource

    init(
        label: LocalizedStringResource,
        minutes: Binding<Int>,
        minuteScale: LoopMinuteScale,
        numberEvery: Int,
        unit: LocalizedStringResource
    ) {
        self.label = label
        self._minutes = minutes
        self.minuteScale = minuteScale
        self.numberEvery = numberEvery
        self.unit = unit
    }

    /// A scale with a detent on every minute up to `maximumMinutes`.
    ///
    /// The plain unstaged case, for a screen that has not moved to one of the
    /// engine's scales yet.
    init(
        label: LocalizedStringResource,
        minutes: Binding<Int>,
        maximumMinutes: Int,
        numberEvery: Int,
        unit: LocalizedStringResource
    ) {
        self.init(
            label: label,
            minutes: minutes,
            minuteScale: LoopMinuteScale(
                range: 0...max(0, maximumMinutes),
                stages: [.init(start: 0, step: 1)]
            ),
            numberEvery: numberEvery,
            unit: unit
        )
    }

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopPalette) private var palette
    @Environment(\.loopInk) private var ink
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Scroll state

    /// Where the scale is standing, in minutes, while it is being moved — `nil`
    /// whenever it is at rest on `minutes`.
    ///
    /// Fractional, because the finger is between detents for all but an instant
    /// of a drag and a scale that jumped detent to detent under the finger
    /// would not be following it.
    ///
    /// This is the one piece of state the component owns, and `PageScaffold`'s
    /// rule about state inside a slot is worth answering rather than ignoring.
    /// It resolves to `nil` the moment the scale comes to rest, so the two
    /// copies of this view are the same drawing except while a finger is on one
    /// of them — and only one copy takes touches. It is also unreachable in
    /// practice: a scale is only ever drawn on a setup or idle state, and those
    /// have no rising area at all, so the second copy is masked to nothing.
    @State private var scrollMinutes: Double?

    /// The value the current drag started from. Read once per gesture, so that
    /// snapping `minutes` mid-drag does not feed back into where the finger
    /// thinks it started.
    @State private var gestureOrigin: Double = 0

    /// Whether a finger is on the scale.
    ///
    /// `scrollMinutes` cannot answer this: it stays set through the settle
    /// after the finger has gone, which is exactly the window in which a new
    /// drag has to be told apart from a continuing one.
    @State private var isDragging = false

    /// Which detent the last tap was for.
    ///
    /// Kept here rather than derived from `minutes`, because `minutes` is a
    /// binding onto the snapshot the frame was built from and cannot answer a
    /// question about what has happened since. This is the view's own state, so
    /// it is current for every callback in a pass.
    @State private var feedback = DetentFeedback()

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.sliderSpacing) {
            header
            scale
        }
        .foregroundStyle(ink.base)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityAdjustableAction { direction in
            let adjusted = switch direction {
            case .increment: minuteScale.next(after: minutes)
            case .decrement: minuteScale.previous(before: minutes)
            @unknown default: minutes
            }
            // Unlike the drag's, this comparison is a limit and not an
            // elision: at either end of the scale the step returns the value
            // it was given, and there is neither a move to write nor a detent
            // to announce. One adjustment is one gesture, so there is no second
            // one to be a pass behind.
            guard adjusted != minutes else { return }
            minutes = adjusted
            // Same reason the drag fires it here: this view is built twice
            // inside `FillSurface`, so anything watching the binding would fire
            // from both copies.
            LoopHaptics.detent()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .loopTextStyle(typography.fieldLabel)

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(verbatim: headerValue)
                    .loopTextStyle(typography.sliderValue)
                    .monospacedDigit()

                Text(minutes < Self.minutesInAnHour ? unit : LoopStrings.hoursUnit)
                    .loopTextStyle(typography.valueUnit)
            }
        }
    }

    // MARK: - Scale

    private var scaleHeight: CGFloat {
        metrics.sliderScaleTopPadding
            + metrics.sliderTickRowHeight
            + metrics.sliderNumberRowTopPadding
            + metrics.sliderNumberRowHeight
    }

    private var scale: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let pitch = LoopMetrics.sliderMinutePitch(width: width)
            // Where minute zero sits. Everything on the scale is drawn from
            // this one number, so the ticks, the numbers and the value under
            // the marker cannot disagree about where the scale is standing.
            let origin = width / 2 - displayedMinutes * pitch

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ticks(origin: origin, pitch: pitch, width: width)
                    numbers(origin: origin, pitch: pitch, width: width)
                }
                .padding(.top, metrics.sliderScaleTopPadding)

                marker
                    // `position` centres the view on the point, which is the
                    // export's `translateX(-50%)`. The marker reaches above the
                    // ticks, so it is measured from the top of the block.
                    .position(x: width / 2, y: metrics.sliderMarkerHeight / 2)
            }
            // The whole block is the target, not just the ticks: the ticks are
            // one point wide and nobody hits a one-point target.
            .contentShape(.rect)
            .gesture(drag(pitch: pitch))
        }
        .frame(height: scaleHeight)
        // The scale runs past both ends of its box in every state that is not
        // at a limit, and a tick spilling into the header or into the control
        // row below would read as a stray line.
        .clipped()
    }

    private func ticks(origin: CGFloat, pitch: CGFloat, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Holds the row open at its full width; the ticks are positioned
            // rather than laid out, so nothing else gives it one.
            Color.clear

            ForEach(visibleDetents(origin: origin, pitch: pitch, width: width), id: \.self) { minute in
                let isMajor = minute.isMultiple(of: LoopMetrics.sliderMajorTickInterval)

                Rectangle()
                    .fill(ink.base)
                    .opacity(isMajor ? LoopMetrics.sliderMajorTickOpacity : LoopMetrics.sliderMinuteTickOpacity)
                    .frame(
                        width: isMajor ? metrics.sliderMajorTickWidth : metrics.sliderMinuteTickWidth,
                        height: isMajor ? metrics.sliderMajorTickHeight : metrics.sliderMinuteTickHeight
                    )
                    // Bottom-aligned in the row, as the export draws it, and
                    // centred on its own minute.
                    .position(
                        x: origin + CGFloat(minute) * pitch,
                        y: metrics.sliderTickRowHeight - tickHeight(isMajor: isMajor) / 2
                    )
            }
        }
        .frame(height: metrics.sliderTickRowHeight)
    }

    private func tickHeight(isMajor: Bool) -> CGFloat {
        isMajor ? metrics.sliderMajorTickHeight : metrics.sliderMinuteTickHeight
    }

    private func numbers(origin: CGFloat, pitch: CGFloat, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            ForEach(visibleNumbers(origin: origin, pitch: pitch, width: width), id: \.self) { value in
                // Centred horizontally on the value — the export's
                // `translateX(-50%)` — but sitting on the top edge of the row,
                // which is where a span with no `top` lands.
                Text(verbatim: Self.numberLabel(minutes: value))
                    .loopTextStyle(typography.scaleNumber)
                    .fixedSize()
                    // A zero-width frame carries no width of its own, so the
                    // label overflows it evenly on both sides and the frame's
                    // edge *is* its centre. Offsetting that to the tick centres
                    // the label on it — the export's `translateX(-50%)` —
                    // without a slot width to invent or to outgrow.
                    .frame(width: 0)
                    .offset(x: origin + CGFloat(value) * pitch)
            }
        }
        .frame(height: metrics.sliderNumberRowHeight)
        .padding(.top, metrics.sliderNumberRowTopPadding)
    }

    private var marker: some View {
        Capsule()
            .fill(palette.marker)
            .frame(width: metrics.sliderMarkerWidth, height: metrics.sliderMarkerHeight)
    }

    // MARK: - What is on screen

    /// The value the scale is currently standing at — the detent it rests on,
    /// or wherever the finger has taken it.
    private var displayedMinutes: CGFloat {
        CGFloat(scrollMinutes ?? Double(minutes))
    }

    /// The detents that fall inside the visible width, in order.
    ///
    /// Walked with `next(after:)` rather than computed, because the step is the
    /// engine's business and staged: below two hours it is a minute, above it
    /// five, and this has no way to know where the boundary is — nor any need
    /// to. Drawing a tick per detent rather than per minute is also what makes
    /// the change of step visible: past the boundary every tick that is left is
    /// a five-minute major, and the scale visibly opens up.
    private func visibleDetents(origin: CGFloat, pitch: CGFloat, width: CGFloat) -> [Int] {
        guard pitch > 0 else { return [] }

        let first = max(minuteScale.range.lowerBound, Int(floor((-origin) / pitch)))
        let last = min(minuteScale.range.upperBound, Int(ceil((width - origin) / pitch)))
        guard first <= last else { return [] }

        var values: [Int] = []
        var value = minuteScale.nearest(to: Double(first))
        while value <= last {
            if value >= first { values.append(value) }
            let following = minuteScale.next(after: value)
            // A detent rule that does not advance would spin here forever, and
            // the top of the range answers itself by design.
            guard following > value else { break }
            value = following
        }
        return values
    }

    /// The numbered values inside the visible width.
    ///
    /// Numbers stay on their own fixed interval rather than on the detents:
    /// past two hours the detents are five minutes apart, and a number under
    /// every one of them would be a wall of digits.
    private func visibleNumbers(origin: CGFloat, pitch: CGFloat, width: CGFloat) -> [Int] {
        guard pitch > 0, numberEvery > 0 else { return [] }

        let first = max(minuteScale.range.lowerBound, Int(floor((-origin) / pitch)))
        let last = min(minuteScale.range.upperBound, Int(ceil((width - origin) / pitch)))
        guard first <= last else { return [] }

        let start = ((first + numberEvery - 1) / numberEvery) * numberEvery
        guard start <= last else { return [] }
        return Array(stride(from: start, through: last, by: numberEvery))
    }

    /// What a number under the scale reads.
    ///
    /// Bare minutes below an hour — `0 15 30 45`, exactly the export's row —
    /// and `h:mm` from an hour on. The old scale stopped at sixty and could
    /// print plain minutes the whole way; this one runs to thirty hours, and
    /// `1755` under a tick is a number nobody converts in their head. The
    /// switch happens at the hour rather than at the two-hour step change
    /// because it is about reading a duration, not about how far apart the
    /// detents are.
    private static func numberLabel(minutes: Int) -> String {
        minutes < minutesInAnHour
            ? String(minutes)
            : LoopTimeFormat.hoursAndMinutes(TimeInterval(minutes) * 60)
    }

    /// The number beside the label, on the same rule as the row.
    ///
    /// The header and the scale are two readings of one value, and a header
    /// saying "1800 min" over a row of `h:mm` would be two answers to the same
    /// question. Under an hour it keeps the export's leading zero — "05 min",
    /// not "5 min" — so the value does not change width as it crosses ten;
    /// `h:mm` has its own padding and needs none added.
    private var headerValue: String {
        minutes < Self.minutesInAnHour
            ? String(format: Self.valueFormat, minutes)
            : LoopTimeFormat.hoursAndMinutes(TimeInterval(minutes) * 60)
    }

    /// Where both readings switch from minutes to `h:mm`.
    ///
    /// Not a design value and not a limit: it is the point at which a duration
    /// stops being said in minutes in ordinary speech, which is why the header
    /// and the row share it rather than each carrying a literal.
    private static let minutesInAnHour = 60

    /// What VoiceOver reads for the current value.
    ///
    /// Built by the system from the duration rather than assembled here, so it
    /// says "1 hour, 25 minutes" in the reader's own language without a catalog
    /// entry for a string that is never drawn.
    private var accessibilityValue: String {
        Duration.seconds(minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .wide))
    }

    // MARK: - Dragging

    private func drag(pitch: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard pitch > 0 else { return }
                if !isDragging {
                    // From where the scale is standing, not from `minutes`.
                    // A finger put down during a settle takes the scale over
                    // from where it visibly is; reading the binding would
                    // start it from the value the settle has not arrived at.
                    gestureOrigin = Double(displayedMinutes)
                    // From where the scale stands, for the same reason: a
                    // finger put down mid-settle has landed on the detent
                    // nearest the drawing, not on the one the binding still
                    // reads, and putting it down is not a choice to be tapped
                    // for.
                    feedback.begin(at: minuteScale.nearest(to: gestureOrigin))
                    isDragging = true
                }

                // Dragging left moves the scale left, which brings larger
                // values under the marker — the same direction a physical dial
                // under a fingertip would turn.
                let moved = gestureOrigin - Double(gesture.translation.width / pitch)
                scrollMinutes = bounded(moved)
                settle(on: minuteScale.nearest(to: moved))
            }
            .onEnded { gesture in
                guard pitch > 0 else { return }

                // A scale that stops dead under the finger is unusable at this
                // range: thirty hours is some ten metres of scale at the drawn
                // density, and reaching the far end without momentum would take
                // dozens of drags. The projection is UIKit's own — the same
                // deceleration every scroll view in the system uses — so a
                // flick here carries as far as a flick anywhere else.
                //
                // Reduce Motion gets no throw. Carrying a value a long way on
                // its own is exactly the kind of unrequested travel the setting
                // asks to be spared, so there the scale stops where the finger
                // left it.
                isDragging = false

                let travel = reduceMotion ? gesture.translation.width : gesture.predictedEndTranslation.width
                let projected = gestureOrigin - Double(travel / pitch)
                let target = minuteScale.nearest(to: projected)

                // The value changes when the scale arrives, not when the finger
                // leaves. Writing it here instead would put the landing number
                // in the header while the marker was still half a second and
                // possibly several hours away from it — the header and the
                // scale are two readings of one value and must never disagree.
                //
                // Resting exactly on the detent and then handing the drawing
                // back to the binding: holding a fractional position after the
                // gesture would leave the scale standing on a stale number the
                // next time the value is set from anywhere else.
                withAnimation(LoopMotion.resolve(LoopMotion.settle, reduceMotion: reduceMotion)) {
                    scrollMinutes = Double(target)
                } completion: {
                    // A finger back on the scale owns it; this settle is over
                    // and its landing value is no longer the answer.
                    guard !isDragging else { return }
                    settle(on: target)
                    scrollMinutes = nil
                }
            }
    }

    /// Moves the value to a detent, with the one tap of feedback that detent is
    /// owed.
    ///
    /// The write is unconditional. Comparing against `minutes` first — the
    /// obvious thing, and what this did — costs a write: the binding's getter
    /// reads the snapshot the frame was built from, so it is one body pass
    /// behind everything written during that pass. Two callbacks in a single
    /// pass and a finger that comes back to the value last drawn, and the
    /// comparison reports "no change" for the detent the finger really is on,
    /// so the value the drag ended on is the one that never arrives. The
    /// setters behind the binding clamp to this same scale and take a value
    /// they already hold without complaint, so nothing was being saved.
    ///
    /// The tap is a different question and is asked separately. It has to be:
    /// a drag reports many times per detent, and one tap per callback is a buzz
    /// rather than the sense of counting minutes. `DetentFeedback` answers it
    /// from this view's own state, which — unlike the binding — is current
    /// within the pass.
    ///
    /// Fired from the gesture rather than by watching `minutes`: this view is
    /// built twice inside `FillSurface`, and a modifier that watches the binding
    /// would fire from both copies.
    private func settle(on value: Int) {
        minutes = value
        if feedback.arrived(at: value) { LoopHaptics.detent() }
    }

    /// Holds the scale inside its range.
    ///
    /// Without this the first and last values could be dragged off the centre
    /// and the scale would show blank under the marker. With it, either end
    /// stops under the marker with half a screen of nothing beyond it, which is
    /// what a fixed centre needs at the edges.
    private func bounded(_ value: Double) -> Double {
        min(Double(minuteScale.range.upperBound), max(Double(minuteScale.range.lowerBound), value))
    }

    /// The export prints a leading zero — "05 min", not "5 min" — so the value
    /// keeps its width as it crosses ten. Sub-hour values only; see
    /// `headerValue`.
    private static let valueFormat = "%02d"
}
