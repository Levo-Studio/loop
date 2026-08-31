import SwiftUI

// MARK: - Stepper

/// A labelled row with a minus, a value and a plus — the interval round count,
/// and nothing else so far.
///
/// No presets. The export deliberately offers one way to change the number, so
/// that the setup screen reads as two sliders and a counter rather than as a
/// form with opinions.
struct LoopStepper: View {

    let label: LocalizedStringResource

    @Binding var value: Int

    let range: ClosedRange<Int>

    /// The unit printed small and dimmed after the value — "×" for rounds.
    var unit: LocalizedStringResource?

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopInk) private var ink

    var body: some View {
        HStack {
            Text(label)
                .loopTextStyle(typography.fieldLabel)

            Spacer(minLength: 0)

            HStack(spacing: metrics.stepperSpacing) {
                circle(Self.minusGlyph, step: -1)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(verbatim: String(value))
                        .loopTextStyle(typography.stepperValue)
                        .monospacedDigit()

                    if let unit {
                        Text(unit)
                            .loopTextStyle(typography.valueUnit)
                    }
                }
                // A floor under the width, not a fixed width — it is what the
                // export sets, and it is enough to keep the row still as the
                // count crosses ten.
                .frame(minWidth: metrics.stepperValueWidth)

                circle(Self.plusGlyph, step: 1)
            }
        }
        .foregroundStyle(ink.base)
    }

    /// Both circles are drawn at full strength in every state of the export,
    /// including at 1 and at 99. The tap is a no-op at the bounds; it does not
    /// announce itself, because the design has no state for that.
    private func circle(_ glyph: String, step: Int) -> some View {
        Button {
            let stepped = min(range.upperBound, max(range.lowerBound, value + step))
            guard stepped != value else { return }
            value = stepped
            // See `ScaleSlider`: fired from the handler, because the view is
            // built twice inside `FillSurface`.
            LoopHaptics.detent()
        } label: {
            Text(verbatim: glyph)
                .loopTextStyle(typography.stepperGlyph)
                .foregroundStyle(ink.base)
                .frame(width: metrics.stepperDiameter, height: metrics.stepperDiameter)
                .overlay {
                    Circle().strokeBorder(ink.hairStrong, lineWidth: metrics.hairlineWidth)
                }
        }
        .buttonStyle(.plain)
    }

    // The export sets a true minus sign, not a hyphen — at this weight and size
    // a hyphen sits too high and too short next to the plus.
    private static let minusGlyph = "\u{2212}"
    private static let plusGlyph = "+"
}
