import SwiftUI

// MARK: - Type style

/// One resolved text role: font, tracking in points, and the opacity and casing
/// that belong to the role rather than to the call site.
nonisolated struct LoopTextStyle: Equatable, Sendable {

    let font: Font

    /// Tracking in **points**. The export writes letter-spacing in `em`; the
    /// conversion `em × fontSize` happens once, in `init`, because SwiftUI's
    /// `.tracking` takes points and doing it at every call site is where the
    /// rounding errors would come from.
    let tracking: CGFloat

    /// Opacity that belongs to the role — the secondary line is 62 % by
    /// definition, not because someone dimmed it.
    let opacity: Double

    /// Whether the role is set in capitals.
    let isUppercased: Bool

    /// Line spacing adjustment in points, or `nil` when the role uses the
    /// font's own leading. Derived from the export's `line-height`.
    let lineHeight: CGFloat?

    init(
        weight: LoopFonts.Weight,
        size: CGFloat,
        trackingEm: CGFloat = 0,
        opacity: Double = 1,
        uppercased: Bool = false,
        lineHeightFactor: CGFloat? = nil
    ) {
        self.font = LoopFonts.font(weight, size: size)
        self.tracking = trackingEm * size
        self.opacity = opacity
        self.isUppercased = uppercased
        self.lineHeight = lineHeightFactor.map { $0 * size }
    }
}

// MARK: - Typography

/// The type scale, resolved for one size class multiplier.
///
/// iPhone renders at 1.0 and iPad at 1.15; every size below is a base value
/// times that factor, exactly as the export does it.
nonisolated struct LoopTypography: Equatable, Sendable {

    /// The size multiplier: 1.0 on iPhone, 1.15 on iPad.
    let scale: CGFloat

    /// Whether the device is in landscape. The big time is the only role that
    /// changes with orientation.
    let isLandscape: Bool

    init(scale: CGFloat, isLandscape: Bool) {
        self.scale = scale
        self.isLandscape = isLandscape
    }

    // MARK: - The big time

    /// The unscaled base size of the big time before auto-scaling.
    private var bigTimeBaseSize: CGFloat { (isLandscape ? 84 : 104) * scale }

    /// The big time, shrunk to fit its own length.
    ///
    /// Five characters ("25:00") is the reference width. Longer strings —
    /// "09:41:07" with seconds, or an hour-long count-up — scale down by
    /// `5 / characterCount` so the glyphs still fit the content column. The
    /// factor is capped at 1 so a shorter string never grows.
    func bigTime(characterCount: Int) -> LoopTextStyle {
        let factor = min(1, 5 / CGFloat(max(characterCount, 1)))
        return LoopTextStyle(
            weight: .light,
            size: bigTimeBaseSize * factor,
            trackingEm: -0.055,
            lineHeightFactor: 0.82
        )
    }

    /// The countdown's idle preview — larger than a label, smaller than the
    /// running time, and with its own line height and tracking.
    var countdownPreview: LoopTextStyle {
        LoopTextStyle(
            weight: .light,
            size: 76 * scale,
            trackingEm: -0.05,
            lineHeightFactor: 0.86
        )
    }

    // MARK: - Labels

    /// The status pill at the top of every timer page.
    var statusPill: LoopTextStyle {
        LoopTextStyle(weight: .medium, size: 11 * scale, trackingEm: 0.14, uppercased: true)
    }

    /// The line under the big time — "of 25:00", "since 09:29".
    var secondaryLine: LoopTextStyle {
        LoopTextStyle(weight: .regular, size: 11 * scale, trackingEm: 0.18, opacity: 0.62, uppercased: true)
    }

    /// A settings section heading.
    var sectionHeading: LoopTextStyle {
        LoopTextStyle(weight: .regular, size: 11 * scale, trackingEm: 0.2, opacity: 0.62, uppercased: true)
    }

    /// A slider's own label, and the interval total underneath the stepper.
    /// Same size as the section heading but a touch tighter, per the export.
    var fieldLabel: LoopTextStyle {
        LoopTextStyle(weight: .regular, size: 11 * scale, trackingEm: 0.16, opacity: 0.62, uppercased: true)
    }

    /// Both buttons of a control row.
    var button: LoopTextStyle {
        LoopTextStyle(weight: .medium, size: 12 * scale, trackingEm: 0.12, uppercased: true)
    }

    // MARK: - Values

    /// The number beside a slider label.
    var sliderValue: LoopTextStyle {
        LoopTextStyle(weight: .regular, size: 15 * scale)
    }

    /// The stepper's number.
    var stepperValue: LoopTextStyle {
        LoopTextStyle(weight: .regular, size: 19 * scale)
    }

    /// The unit that trails a value — " min", " ×".
    var valueUnit: LoopTextStyle {
        LoopTextStyle(weight: .regular, size: 10 * scale, opacity: 0.62)
    }

    /// The − and + glyphs inside the stepper circles.
    var stepperGlyph: LoopTextStyle {
        LoopTextStyle(weight: .regular, size: 15 * scale)
    }

    /// A number printed under the slider scale.
    var scaleNumber: LoopTextStyle {
        LoopTextStyle(weight: .regular, size: 10 * scale, trackingEm: 0.1, opacity: 0.62)
    }

    // MARK: - Settings

    /// The label of a settings row.
    var settingsRow: LoopTextStyle {
        LoopTextStyle(weight: .regular, size: 14 * scale, trackingEm: -0.01)
    }

    /// The name of an accent in the accent list.
    var accentName: LoopTextStyle {
        LoopTextStyle(weight: .regular, size: 12.5 * scale, trackingEm: 0.06)
    }

    /// The "active" marker on the selected accent row.
    var accentActiveMarker: LoopTextStyle {
        LoopTextStyle(weight: .regular, size: 9.5 * scale, trackingEm: 0.16, opacity: 0.62, uppercased: true)
    }

    /// The line at the bottom of settings.
    var footer: LoopTextStyle {
        LoopTextStyle(weight: .regular, size: 10 * scale, trackingEm: 0.16, opacity: 0.4, uppercased: true)
    }
}

// MARK: - Applying a style

extension View {

    /// Applies a text role. Casing is part of the role, so it is applied with
    /// `textCase` here rather than by uppercasing the string in the catalog —
    /// the catalog holds the words as they are written.
    func loopTextStyle(_ style: LoopTextStyle) -> some View {
        font(style.font)
            .tracking(style.tracking)
            .textCase(style.isUppercased ? .uppercase : nil)
            .opacity(style.opacity)
    }
}

// MARK: - Environment

extension EnvironmentValues {

    /// The type scale for the current idiom and orientation.
    @Entry var loopTypography = LoopTypography(scale: 1, isLandscape: false)
}
