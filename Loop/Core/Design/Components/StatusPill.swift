import SwiftUI

// MARK: - Status pill

/// The rounded label at the top of every timer page.
///
/// Two shapes in the export, and the difference carries meaning rather than
/// decoration: while something is running or waiting the pill carries the accent
/// dot on the lighter chip tone; once a run is finished the dot is gone and the
/// tone is a step stronger, because there is no longer a state to indicate.
struct StatusPill: View {

    // MARK: - Emphasis

    enum Emphasis {

        /// Accent dot, chip background — every state except finished.
        case marked

        /// No dot, the stronger tone — the finished state.
        case solid
    }

    let label: LocalizedStringResource

    /// The trailing half of a two-part label, dimmed against the first —
    /// "Paused" plus "Focus · 02 / 04".
    var detail: LocalizedStringResource?

    var emphasis: Emphasis = .marked

    @Environment(\.loopPalette) private var palette
    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopInk) private var ink

    var body: some View {
        HStack(spacing: metrics.pillSpacing) {
            if emphasis == .marked {
                Circle()
                    // The dot keeps the accent colour on both sides of the fill
                    // edge. It is the one thing in the layout that is not
                    // two-toned, because it names the accent rather than the
                    // surface it sits on.
                    .fill(palette.marker)
                    .frame(width: metrics.pillDotSize, height: metrics.pillDotSize)
            }

            Text(label)

            if let detail {
                Text(detail)
                    .opacity(Self.detailOpacity)
            }
        }
        .loopTextStyle(typography.statusPill)
        .foregroundStyle(ink.base)
        .padding(metrics.pillPadding)
        .background(emphasis == .marked ? ink.chip : ink.chipStrong, in: .capsule)
    }

    /// The second half of the label reads as a qualifier, not a second heading.
    private static let detailOpacity: Double = 0.62
}
