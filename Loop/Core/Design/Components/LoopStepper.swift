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
                circle(Self.minusGlyph, step: -1, isEnabled: value > range.lowerBound)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(verbatim: String(value))
                        .loopTextStyle(typography.stepperValue)
                        .monospacedDigit()

                    if let unit {
                        Text(unit)
                            .loopTextStyle(typography.valueUnit)
                    }
                }
                // A fixed width, so the row does not jump when the count
                // crosses ten.
                .frame(minWidth: metrics.stepperValueWidth)

                circle(Self.plusGlyph, step: 1, isEnabled: value < range.upperBound)
            }
        }
        .foregroundStyle(ink.base)
        .sensoryFeedback(.selection, trigger: value)
    }

    private func circle(_ glyph: String, step: Int, isEnabled: Bool) -> some View {
        Button {
            value = min(range.upperBound, max(range.lowerBound, value + step))
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
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : LoopMetrics.disabledOpacity)
    }

    // The export sets a true minus sign, not a hyphen — at this weight and size
    // a hyphen sits too high and too short next to the plus.
    private static let minusGlyph = "\u{2212}"
    private static let plusGlyph = "+"
}
