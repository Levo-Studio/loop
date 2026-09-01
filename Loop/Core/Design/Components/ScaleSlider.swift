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
///
/// **The scale is laid out in detents, not in minutes.** One slot of the
/// export's sixty-one is one selectable value wherever you are on the scale, so
/// below two hours it is a minute — the export exactly — and above it five.
/// Laid out per minute the coarse part stretches over four values in five that
/// nothing can land on, and since the scale stops where the finger stops, that
/// distance is paid for by hand: thirty hours took about thirty full-width
/// swipes and now takes about eight.
///
/// The step change is still visible, and by the same means the export already
/// uses to say "this is a five-minute mark": the taller, wider, darker major
/// tick. Below two hours one tick in five is a major; above it *every* detent
/// is a five-minute value, so every tick is. The scale changes at the boundary
/// from a rhythm of short hairlines with a tall one every fifth to a solid row
/// of tall ones — a change of texture rather than of spacing, at exactly the
/// minute where the step changes, drawn with nothing that was not already
/// there.
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

    /// Where the scale stood when the current drag's translation was zero, in
    /// **detents** — the coordinate the scale is laid out in, so that a point
    /// of travel is a point of travel wherever on the scale it happens.
    ///
    /// Taken once when the finger lands, so that snapping `minutes` mid-drag
    /// does not feed back into where the finger thinks it started — and moved
    /// again only at the ends of the scale, where the finger travels and the
    /// scale cannot follow.
    @State private var gestureOriginDetents: Double = 0

    /// Whether a finger is on the scale.
    ///
    /// `scrollMinutes` cannot answer this: it stays set through the snap after
    /// the finger has gone, which is exactly the window in which a new drag has
    /// to be told apart from a continuing one.
    @State private var isDragging = false

    /// Where the scale is actually drawn, which during the snap is not what the
    /// state says. See `DrawnPosition`.
    @State private var drawn = DrawnPosition()

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
            let pitch = LoopMetrics.sliderDetentPitch(width: width)
            // Where detent zero sits. Everything on the scale is drawn from
            // this one number, so the ticks, the numbers and the value under
            // the marker cannot disagree about where the scale is standing.
            let origin = width / 2 - CGFloat(minuteScale.detentOffset(of: Double(displayedMinutes))) * pitch

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
        .modifier(DrawnPositionReader(minutes: Double(displayedMinutes), position: drawn))
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
                        x: x(ofMinute: minute, origin: origin, pitch: pitch),
                        y: metrics.sliderTickRowHeight - tickHeight(isMajor: isMajor) / 2
                    )
            }
        }
        .frame(height: metrics.sliderTickRowHeight)
    }

    private func tickHeight(isMajor: Bool) -> CGFloat {
        isMajor ? metrics.sliderMajorTickHeight : metrics.sliderMinuteTickHeight
    }

    /// Where a minute value sits across the scale.
    ///
    /// Through the detent coordinate, so a tick, its number and the marker over
    /// it are placed by one rule. Asking the scale rather than multiplying by
    /// the value is what keeps this drawing ignorant of where the steps change,
    /// which is the engine's business and not the picture's.
    private func x(ofMinute minute: Int, origin: CGFloat, pitch: CGFloat) -> CGFloat {
        origin + CGFloat(minuteScale.detentOffset(of: Double(minute))) * pitch
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
                    .offset(x: x(ofMinute: value, origin: origin, pitch: pitch))
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

    /// The minute values at the two edges of the visible width, clamped to the
    /// scale.
    ///
    /// Read back through the detent coordinate, because that is the coordinate
    /// the scale is laid out in: an edge is so many slots from the origin, and
    /// how many minutes that is depends on which stage it lands in.
    private func visibleMinutes(origin: CGFloat, pitch: CGFloat, width: CGFloat) -> ClosedRange<Double> {
        let leading = minuteScale.minutes(atDetentOffset: Double((-origin) / pitch))
        let trailing = minuteScale.minutes(atDetentOffset: Double((width - origin) / pitch))
        return min(leading, trailing)...max(leading, trailing)
    }

    /// The detents that fall inside the visible width, in order.
    ///
    /// Walked with `next(after:)` rather than computed, because the step is the
    /// engine's business and staged: below two hours it is a minute, above it
    /// five, and this has no way to know where the boundary is — nor any need
    /// to. A slot is a detent, so the walk is also what bounds the loop: sixty
    /// or so of them cross the width whatever the step is.
    ///
    /// The ends are `nearest(to:)` rather than a floor and a ceiling, so at
    /// most one tick beyond each edge is drawn. That one is behind the clip,
    /// and it is the cheap way of never leaving a gap at an edge.
    private func visibleDetents(origin: CGFloat, pitch: CGFloat, width: CGFloat) -> [Int] {
        guard pitch > 0 else { return [] }

        let minutes = visibleMinutes(origin: origin, pitch: pitch, width: width)
        let last = minuteScale.nearest(to: minutes.upperBound)

        var values: [Int] = []
        var value = minuteScale.nearest(to: minutes.lowerBound)
        while value <= last {
            values.append(value)
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
    /// Numbers stay on a minute interval rather than on the detents: five
    /// minutes apart is fifteen points on a phone, and a number under every one
    /// of them would be a wall of digits overlapping each other.
    private func visibleNumbers(origin: CGFloat, pitch: CGFloat, width: CGFloat) -> [Int] {
        guard pitch > 0, numberEvery > 0 else { return [] }

        let minutes = visibleMinutes(origin: origin, pitch: pitch, width: width)
        let first = Int(minutes.lowerBound.rounded(.down))
        let last = Int(minutes.upperBound.rounded(.up))

        var values: [Int] = []
        let interval = numberInterval(at: first)
        var value = ((first + interval - 1) / interval) * interval
        while value <= last {
            values.append(value)
            value += numberInterval(at: value)
        }
        return values
    }

    /// How often a number is printed at a value.
    ///
    /// `numberEvery` — the export's density — wherever the detents are whole
    /// minutes, which is the whole of the scale the export drew. Where they are
    /// coarser the row prints whole hours instead.
    ///
    /// Two reasons, and the geometric one is the one that forces it. A slot is
    /// a detent, so above two hours fifteen minutes is three slots: on a phone
    /// that is sixteen points between labels that are thirty-five wide, which
    /// is a smear rather than a row. An hour is twelve slots — within a slot or
    /// three of the density the export draws, so the row does not visibly
    /// change rhythm at the boundary.
    ///
    /// The other is that it is the rule the row already follows. A number
    /// switches to `h:mm` at an hour because past that point a duration is read
    /// in hours rather than in minutes; a scale whose detents have stopped
    /// being minutes is that same reading taken one step further, so it is
    /// numbered in the unit it is read in.
    /// Static and `nonisolated` so the rule can be asked without a view: it is
    /// pure arithmetic over two values, and a row that becomes a smear at one
    /// end of one scale is not something a rendered check would catch reliably.
    nonisolated static func numberInterval(
        on minuteScale: LoopMinuteScale,
        every numberEvery: Int,
        at minutes: Int
    ) -> Int {
        minuteScale.step(at: minutes) == 1 ? numberEvery : minutesInAnHour
    }

    private func numberInterval(at minutes: Int) -> Int {
        Self.numberInterval(on: minuteScale, every: numberEvery, at: minutes)
    }

    /// What a number under the scale reads.
    ///
    /// Bare minutes below an hour — `0 15 30 45`, exactly the export's row —
    /// and `h:mm` from an hour on. The old scale stopped at sixty and could
    /// print plain minutes the whole way; this one runs to thirty hours, and
    /// `1755` under a tick is a number nobody converts in their head. The
    /// switch happens at the hour rather than at the two-hour step change
    /// because it is about reading a duration, not about how far apart the
    /// detents are. How *often* a number is printed is the other question and
    /// does turn on the detents; see `numberInterval(at:)`.
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
                if !isDragging { takeOver() }
                move(translation: gesture.translation.width, pitch: pitch)
            }
            .onEnded { gesture in
                guard pitch > 0 else { return }

                // **The scale stops where the finger stops.** No projection of
                // where a flick "would have" gone: a control that keeps turning
                // after the hand has left is one you have to correct afterwards,
                // and this one is touched for every timer anybody sets.
                //
                // The distance is paid for by making every point of it buy a
                // value — a slot is a detent — rather than by the control
                // carrying on without a hand on it.
                isDragging = false

                let landed = move(translation: gesture.translation.width, pitch: pitch)
                let target = minuteScale.nearest(to: landed)

                // The snap to the detent, and only that: at most half a detent
                // of travel, over `selection`, which is the app's length for a
                // change the user just made. A scale left resting between two
                // values would be claiming a value it is not on.
                //
                // The value follows the scale rather than the finger — it is
                // written when the snap arrives — and the drawing goes back to
                // the binding at the same moment, because holding a fractional
                // position after the gesture would leave the scale standing on a
                // stale number the next time the value is set from elsewhere.
                withAnimation(LoopMotion.resolve(LoopMotion.selection, reduceMotion: reduceMotion)) {
                    scrollMinutes = Double(target)
                } completion: {
                    // A finger back on the scale owns it; this snap is over and
                    // its landing value is no longer the answer.
                    guard !isDragging else { return }
                    settle(on: target)
                    scrollMinutes = nil
                }
            }
    }

    /// Hands the scale to a finger that has just landed on it.
    ///
    /// From where the scale is **drawn**, which is neither `minutes` — a
    /// binding onto the frame's snapshot — nor `scrollMinutes`, which during
    /// the snap already holds the detent the snap is travelling to. Taking the
    /// second would make the scale jump forward under the finger that came down
    /// to stop it, which is the opposite of what putting a finger on something
    /// means.
    private func takeOver() {
        let visible = drawn.minutes ?? Double(displayedMinutes)

        // Ends the snap where it has got to. Assigning inside a transaction
        // with no animation is what removes the one still running; leaving it
        // to run would keep moving the scale under a finger that is now
        // driving it.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { scrollMinutes = visible }

        gestureOriginDetents = minuteScale.detentOffset(of: visible)
        // Landing on the scale is not choosing the detent under it, so the
        // detent the finger arrives on is recorded rather than announced.
        feedback.begin(at: minuteScale.nearest(to: visible))
        isDragging = true
    }

    /// Puts the scale where this gesture's translation says it should be, and
    /// answers where that turned out to be.
    ///
    /// Dragging left moves the scale left, which brings larger values under the
    /// marker — the direction a physical dial under a fingertip would turn.
    ///
    /// Counted in detents throughout and converted to minutes at the end: a
    /// point of finger travel is a fixed fraction of a slot, and a slot is a
    /// selectable value. That is the whole of the change — one pitch of drag
    /// buys one detent above two hours as it always did below it.
    @discardableResult
    private func move(translation: CGFloat, pitch: CGFloat) -> Double {
        let reached = gestureOriginDetents - Double(translation / pitch)
        let held = boundedDetents(reached)

        // Past an end the finger keeps travelling and the scale cannot follow.
        // Moving the origin by exactly that overshoot rather than remembering
        // it is what makes the way back immediate: without this, a finger that
        // has run a screen past zero has to give every point of it back before
        // the scale moves at all, which reads as the control fighting the hand.
        gestureOriginDetents += held - reached

        let minutes = minuteScale.minutes(atDetentOffset: held)
        scrollMinutes = minutes
        settle(on: minuteScale.nearest(to: minutes))
        return minutes
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

    /// Holds the scale inside its range, in detents.
    ///
    /// Without this the first and last values could be dragged off the centre
    /// and the scale would show blank under the marker. With it, either end
    /// stops under the marker with half a screen of nothing beyond it, which is
    /// what a fixed centre needs at the edges.
    ///
    /// Clamped here rather than after the conversion because the overshoot the
    /// caller gives back has to be in the units it travelled in; a clamp in
    /// minutes would hand back five times too little above two hours and the
    /// scale would lag the finger on the way off an end.
    private func boundedDetents(_ value: Double) -> Double {
        let lower = minuteScale.detentOffset(of: Double(minuteScale.range.lowerBound))
        let upper = minuteScale.detentOffset(of: Double(minuteScale.range.upperBound))
        return min(upper, max(lower, value))
    }

    /// The export prints a leading zero — "05 min", not "5 min" — so the value
    /// keeps its width as it crosses ten. Sub-hour values only; see
    /// `headerValue`.
    private static let valueFormat = "%02d"
}

// MARK: - Where the scale is drawn

/// The position the scale is being drawn at, which for the length of the snap
/// is not the position the state holds.
///
/// `withAnimation` sets the value immediately and interpolates only the
/// drawing, so the state answers "where it is going" throughout. That is the
/// wrong answer for exactly one question — where a finger arriving mid-snap
/// takes the scale over from — and the right one everywhere else, so the
/// drawn position is kept beside it rather than replacing it.
///
/// A reference and not `@State`: it is written on every frame of an animation,
/// and writing state there would invalidate the view whose drawing is being
/// measured.
private final class DrawnPosition {
    var minutes: Double?
}

/// Copies the interpolation out of an animation as it runs.
///
/// The only way to read a value SwiftUI is animating: `animatableData` is what
/// the interpolation is applied to, so its setter is called once per frame with
/// the position actually about to be drawn.
private struct DrawnPositionReader: ViewModifier, Animatable {

    var minutes: Double

    let position: DrawnPosition

    var animatableData: Double {
        get { minutes }
        set {
            minutes = newValue
            position.minutes = newValue
        }
    }

    func body(content: Content) -> some View { content }
}
