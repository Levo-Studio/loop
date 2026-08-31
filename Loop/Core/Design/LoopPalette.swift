import SwiftUI

// MARK: - Ink

/// One ink and the tones derived from it.
///
/// The app has two inks at any moment: the one on the background and the one on
/// the fill. Every derived tone is the same alpha over whichever ink applies,
/// so `FillSurface` can swap the whole set at the fill edge by putting a
/// different `LoopInk` into the environment — no call site repeats itself.
nonisolated struct LoopInk: Equatable, Sendable {

    /// The ink at full strength: text, active nav dot, stepper glyphs.
    let base: Color

    // The four alphas from the design export. They are properties rather than
    // literals at the call sites so the on-fill layer cannot drift from the
    // background layer.
    private static let hairAlpha = 0.15
    private static let chipAlpha = 0.08
    private static let chipStrongAlpha = 0.12
    private static let hairStrongAlpha = 0.26

    /// Dividers and inactive borders.
    var hair: Color { base.opacity(Self.hairAlpha) }

    /// The status pill background.
    var chip: Color { base.opacity(Self.chipAlpha) }

    /// The primary button fill.
    var chipStrong: Color { base.opacity(Self.chipStrongAlpha) }

    /// The secondary button border and the stepper circles.
    var hairStrong: Color { base.opacity(Self.hairStrongAlpha) }
}

// MARK: - Palette

/// Every colour the app draws, resolved for one accent and one colour scheme.
nonisolated struct LoopPalette: Equatable, Sendable {

    let accent: LoopAccent
    let scheme: ColorScheme

    init(accent: LoopAccent, scheme: ColorScheme) {
        self.accent = accent
        self.scheme = scheme
    }

    /// The page background.
    var background: Color { accent.background(scheme) }

    /// The rising area — the app's only progress indicator.
    var fill: Color { accent.fill(scheme).color }

    /// The small accent marks: pill dot, slider marker, settings swatch. Not
    /// two-toned; they keep their colour on both sides of the fill edge.
    var marker: Color { accent.marker(scheme).color }

    /// The ink for everything above the fill edge.
    var inkOnBackground: LoopInk { LoopInk(base: accent.foreground(scheme)) }

    /// The ink for everything below it, chosen by the fill's own lightness.
    var inkOnFill: LoopInk { LoopInk(base: accent.fill(scheme).onFillInk) }

    /// The swatch colour for `accent` shown in the settings list, resolved in
    /// this palette's scheme. Settings shows all four at once, so the marker
    /// colour of a foreign accent is needed without switching palettes.
    func swatch(for accent: LoopAccent) -> Color {
        accent.marker(scheme).color
    }
}

// MARK: - Environment

extension EnvironmentValues {

    /// The palette for the chosen accent and the current colour scheme.
    @Entry var loopPalette = LoopPalette(accent: .default, scheme: .light)

    /// The ink the enclosing layer draws in.
    ///
    /// This is what makes the two-tone edge free at the call site: `FillSurface`
    /// renders the same content twice and hands each copy a different ink, so a
    /// button or a dot deep inside a screen resolves to the right tone without
    /// knowing the fill exists.
    @Entry var loopInk = LoopPalette(accent: .default, scheme: .light).inkOnBackground
}
