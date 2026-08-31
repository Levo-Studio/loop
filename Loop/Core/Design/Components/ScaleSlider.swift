import SwiftUI

// MARK: - Scale slider

/// The minute scale used to set a duration — the countdown's length, the
/// interval's focus and break blocks.
///
/// It is not a track with a knob. The scale itself is the control: a tick per
/// minute, a taller one every five, a number every `numberEvery`, and a bar in
/// the accent marking the value. Reading it tells you the number without the
/// header, which is why the header can stay as quiet as it is.
struct ScaleSlider: View {

    let label: LocalizedStringResource

    @Binding var minutes: Int

    /// Always starts at zero — the scale is a duration, and a duration has a
    /// meaningful bottom end.
    let maximumMinutes: Int

    /// How often a number is printed: every 15 minutes on the hour-long scales,
    /// every 10 on the half-hour break scale.
    let numberEvery: Int

    /// The unit after the value in the header.
    var unit: LocalizedStringResource

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopPalette) private var palette
    @Environment(\.loopInk) private var ink

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.sliderSpacing) {
            header
            scale
        }
        .foregroundStyle(ink.base)
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

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ticks
                    numbers(width: width)
                }
                .padding(.top, metrics.sliderScaleTopPadding)

                marker
                    // `position` centres the view on the point, which is the
                    // export's `translateX(-50%)`. The marker reaches above the
                    // ticks, so it is measured from the top of the block.
                    .position(x: width * fraction, y: metrics.sliderMarkerHeight / 2)
            }
            // The whole block is the target, not just the ticks: the ticks are
            // one point wide and nobody hits a one-point target.
            .contentShape(.rect)
            .gesture(drag(width: width))
        }
        .frame(height: scaleHeight)
    }

    private var ticks: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(0...maximumMinutes, id: \.self) { minute in
                let isMajor = minute.isMultiple(of: LoopMetrics.sliderMajorTickInterval)

                Rectangle()
                    .fill(ink.base)
                    .opacity(isMajor ? LoopMetrics.sliderMajorTickOpacity : LoopMetrics.sliderMinuteTickOpacity)
                    .frame(
                        width: isMajor ? metrics.sliderMajorTickWidth : metrics.sliderMinuteTickWidth,
                        height: isMajor ? metrics.sliderMajorTickHeight : metrics.sliderMinuteTickHeight
                    )
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: metrics.sliderTickRowHeight, alignment: .bottom)
    }

    private func numbers(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Holds the row open at its full width even when no number lands on
            // the right-hand edge.
            Color.clear

            ForEach(numberValues, id: \.self) { value in
                // Centred horizontally on the value — the export's
                // `translateX(-50%)` — but sitting on the top edge of the row,
                // which is where a span with no `top` lands.
                Text(verbatim: String(value))
                    .loopTextStyle(typography.scaleNumber)
                    .fixedSize()
                    .frame(width: Self.numberSlotWidth)
                    .offset(x: width * CGFloat(value) / CGFloat(maximumMinutes) - Self.numberSlotWidth / 2)
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

    // MARK: - Value

    private var fraction: CGFloat {
        guard maximumMinutes > 0 else { return 0 }
        return CGFloat(minutes) / CGFloat(maximumMinutes)
    }

    private var numberValues: [Int] {
        stride(from: 0, through: maximumMinutes, by: numberEvery).map { $0 }
    }

    private func drag(width: CGFloat) -> some Gesture {
        // Zero minimum distance, so a tap on the scale sets the value as well
        // as a drag along it.
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard width > 0 else { return }
                let position = min(1, max(0, gesture.location.x / width))
                let snapped = Int((position * CGFloat(maximumMinutes)).rounded())
                if snapped != minutes {
                    minutes = snapped
                    // Fired here rather than by watching `minutes`: this view
                    // is built twice inside `FillSurface`, and a modifier that
                    // watches the binding would fire from both copies. One
                    // tick per detent is what makes the drag feel like
                    // counting minutes rather than sliding a value.
                    LoopHaptics.detent()
                }
            }
    }

    /// A slot wide enough for any number on either scale, so the label can be
    /// centred on its tick by offsetting rather than by `position`, which would
    /// also centre it vertically in the row.
    private static let numberSlotWidth: CGFloat = 100

    /// The export prints a leading zero — "05 min", not "5 min" — so the value
    /// keeps its width as it crosses ten.
    private static let valueFormat = "%02d"
}
