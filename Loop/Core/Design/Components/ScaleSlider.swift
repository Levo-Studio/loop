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

    /// The values the scale may stop on, and the range it draws.
    let detents: ScaleDetents

    /// How often a number is printed under the scale, in minutes.
    ///
    /// Comes from `LoopMetrics.durationNumberInterval` or
    /// `LoopMetrics.breakNumberInterval`. Deliberately has no default: a
    /// wrong-but-plausible density is the kind of thing that survives review,
    /// so each scale has to say which of the two it is.
    let numberEvery: Int

    /// The unit after the value in the header.
    let unit: LocalizedStringResource

    init(
        label: LocalizedStringResource,
        minutes: Binding<Int>,
        detents: ScaleDetents,
        numberEvery: Int,
        unit: LocalizedStringResource
    ) {
        self.label = label
        self._minutes = minutes
        self.detents = detents
        self.numberEvery = numberEvery
        self.unit = unit
    }

    /// A scale with a detent on every minute up to `maximumMinutes`.
    ///
    /// The plain arithmetic case, for a screen whose range is not staged.
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
            detents: .everyMinute(through: maximumMinutes),
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
            case .increment: detents.next(after: minutes)
            case .decrement: detents.previous(before: minutes)
            @unknown default: minutes
            }
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
                Text(verbatim: String(format: Self.valueFormat, minutes))
                    .loopTextStyle(typography.sliderValue)
                    .monospacedDigit()

                Text(unit)
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
                    .frame(width: Self.numberSlotWidth)
                    .offset(x: origin + CGFloat(value) * pitch - Self.numberSlotWidth / 2)
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

        let first = max(detents.range.lowerBound, Int(floor((-origin) / pitch)))
        let last = min(detents.range.upperBound, Int(ceil((width - origin) / pitch)))
        guard first <= last else { return [] }

        var values: [Int] = []
        var value = detents.nearest(to: Double(first))
        while value <= last {
            if value >= first { values.append(value) }
            let following = detents.next(after: value)
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

        let first = max(detents.range.lowerBound, Int(floor((-origin) / pitch)))
        let last = min(detents.range.upperBound, Int(ceil((width - origin) / pitch)))
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
        minutes < 60
            ? String(minutes)
            : LoopTimeFormat.hoursAndMinutes(TimeInterval(minutes) * 60)
    }

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
                if scrollMinutes == nil { gestureOrigin = Double(minutes) }

                // Dragging left moves the scale left, which brings larger
                // values under the marker — the same direction a physical dial
                // under a fingertip would turn.
                let moved = gestureOrigin - Double(gesture.translation.width / pitch)
                scrollMinutes = bounded(moved)
                settle(on: detents.nearest(to: moved))
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
                let travel = reduceMotion ? gesture.translation.width : gesture.predictedEndTranslation.width
                let projected = gestureOrigin - Double(travel / pitch)
                let target = detents.nearest(to: projected)
                settle(on: target)

                // Rest exactly on the detent, then hand the drawing back to the
                // binding. Holding a fractional position after the gesture
                // would leave the scale standing on a stale number the next
                // time the value is set from anywhere else.
                withAnimation(LoopMotion.resolve(LoopMotion.settle, reduceMotion: reduceMotion)) {
                    scrollMinutes = Double(target)
                } completion: {
                    scrollMinutes = nil
                }
            }
    }

    /// Moves the value to a detent, with the one tap of feedback that detent is
    /// owed.
    ///
    /// Fired from the gesture rather than by watching `minutes`: this view is
    /// built twice inside `FillSurface`, and a modifier that watches the binding
    /// would fire from both copies. One tick per detent is what makes the drag
    /// feel like counting minutes rather than sliding a value — and the guard is
    /// what keeps it to one, including on a flick, where the value crosses
    /// hundreds of detents and only the one it lands on is a choice.
    private func settle(on value: Int) {
        guard value != minutes else { return }
        minutes = value
        LoopHaptics.detent()
    }

    /// Holds the scale inside its range.
    ///
    /// Without this the first and last values could be dragged off the centre
    /// and the scale would show blank under the marker. With it, either end
    /// stops under the marker with half a screen of nothing beyond it, which is
    /// what a fixed centre needs at the edges.
    private func bounded(_ value: Double) -> Double {
        min(Double(detents.range.upperBound), max(Double(detents.range.lowerBound), value))
    }

    /// A slot wide enough for any number on the scale, so the label can be
    /// centred on its tick by offsetting rather than by `position`, which would
    /// also centre it vertically in the row.
    private static let numberSlotWidth: CGFloat = 100

    /// The export prints a leading zero — "05 min", not "5 min" — so the value
    /// keeps its width as it crosses ten.
    private static let valueFormat = "%02d"
}
