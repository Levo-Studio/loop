import SwiftUI

// MARK: - Control row

/// The pair of buttons at the bottom of every timer page: a filled primary and
/// an outlined secondary, always both, always the same width.
///
/// A disabled button dims to 45 % and stays where it is. That is deliberate in
/// the export — Skip is visible but dead during a focus block, and Reset is dead
/// before a timer has run. Hiding either would move the row and make the page
/// twitch every time a block changes.
struct ControlRow: View {

    // MARK: - Item

    struct Item {

        let title: LocalizedStringResource
        var isEnabled = true
        let action: () -> Void

        init(_ title: LocalizedStringResource, isEnabled: Bool = true, action: @escaping () -> Void) {
            self.title = title
            self.isEnabled = isEnabled
            self.action = action
        }
    }

    let primary: Item
    let secondary: Item

    @Environment(\.loopMetrics) private var metrics

    var body: some View {
        HStack(spacing: metrics.controlRowSpacing) {
            ControlButton(item: primary, role: .primary)
            ControlButton(item: secondary, role: .secondary)
        }
    }
}

// MARK: - Control button

/// One button of a control row. Not public API on its own — a lone button never
/// appears in the design, and offering one would invite a screen to build a row
/// that does not match the other four.
private struct ControlButton: View {

    enum Role {

        /// Filled with the stronger chip tone.
        case primary

        /// Outlined with the stronger hairline.
        case secondary
    }

    let item: ControlRow.Item
    let role: Role

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopInk) private var ink

    var body: some View {
        Button(action: item.action) {
            Text(item.title)
                .loopTextStyle(typography.button)
                .foregroundStyle(ink.base)
                .frame(maxWidth: .infinity)
                .padding(.vertical, metrics.buttonVerticalPadding)
                .background(background)
        }
        // The plain style keeps SwiftUI from tinting the label or shrinking it
        // on press; the design has no press state beyond the system's own.
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
        .opacity(item.isEnabled ? 1 : LoopMetrics.disabledOpacity)
    }

    @ViewBuilder private var background: some View {
        switch role {
        case .primary:
            Capsule().fill(ink.chipStrong)
        case .secondary:
            Capsule().strokeBorder(ink.hairStrong, lineWidth: metrics.hairlineWidth)
        }
    }
}
