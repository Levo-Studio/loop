import SwiftUI

// MARK: - Accent

/// The four accents the user can pick from. One hue each; light and dark take
/// two lightnesses of that hue and never two different colours.
///
/// The raw values are stable identifiers — they are what `UserDefaults` holds,
/// so renaming one breaks a stored preference. The visible names come from the
/// string catalog, not from here.
nonisolated enum LoopAccent: String, CaseIterable, Identifiable, Sendable {
    case petrol
    case amber
    case lilac
    case graphite

    /// The accent a fresh install starts on.
    static let `default` = LoopAccent.petrol

    var id: String { rawValue }

    // MARK: - Fill

    /// The colour of the rising area, per colour scheme.
    func fill(_ scheme: ColorScheme) -> OKLCH {
        switch self {
        case .petrol: scheme.pick(light: OKLCH(0.55, 0.09, 205), dark: OKLCH(0.40, 0.08, 205))
        case .amber: scheme.pick(light: OKLCH(0.72, 0.125, 72), dark: OKLCH(0.48, 0.10, 72))
        case .lilac: scheme.pick(light: OKLCH(0.58, 0.105, 305), dark: OKLCH(0.41, 0.09, 305))
        case .graphite: scheme.pick(light: OKLCH(0.34, 0.008, 250), dark: OKLCH(0.70, 0.008, 250))
        }
    }

    // MARK: - Marker

    /// The colour of the small accent marks — the status pill dot, the slider
    /// marker, the settings swatch. In dark mode these sit on the background
    /// rather than on the fill, so they need more lightness than the fill has.
    /// Graphite is the exception: its fill is already a neutral that reads at
    /// both ends, so marker and fill are the same colour.
    func marker(_ scheme: ColorScheme) -> OKLCH {
        switch self {
        case .petrol: scheme.pick(light: OKLCH(0.55, 0.09, 205), dark: OKLCH(0.68, 0.10, 205))
        case .amber: scheme.pick(light: OKLCH(0.72, 0.125, 72), dark: OKLCH(0.75, 0.125, 72))
        case .lilac: scheme.pick(light: OKLCH(0.58, 0.105, 305), dark: OKLCH(0.65, 0.105, 305))
        case .graphite: fill(scheme)
        }
    }

    // MARK: - Ground

    /// The page background. Barely tinted towards the accent hue, so the app
    /// does not read as four skins over one grey.
    func background(_ scheme: ColorScheme) -> Color {
        switch self {
        case .petrol: scheme.pick(light: Color(hex: 0xf1f5f4), dark: Color(hex: 0x0d1213))
        case .amber: scheme.pick(light: Color(hex: 0xf6f4ee), dark: Color(hex: 0x12110c))
        case .lilac: scheme.pick(light: Color(hex: 0xf4f2f6), dark: Color(hex: 0x100e13))
        case .graphite: scheme.pick(light: Color(hex: 0xf4f4f3), dark: Color(hex: 0x0f1011))
        }
    }

    /// The ink on the background — text, dots, borders before any alpha.
    func foreground(_ scheme: ColorScheme) -> Color {
        switch self {
        case .petrol: scheme.pick(light: Color(hex: 0x111a1b), dark: Color(hex: 0xe6f0f0))
        case .amber: scheme.pick(light: Color(hex: 0x1a1710), dark: Color(hex: 0xf2ecdf))
        case .lilac: scheme.pick(light: Color(hex: 0x17141b), dark: Color(hex: 0xece8f2))
        case .graphite: scheme.pick(light: Color(hex: 0x16171a), dark: Color(hex: 0xeceded))
        }
    }
}

// MARK: - On-fill rule

nonisolated extension OKLCH {

    /// Lightness above which a fill needs dark ink rather than light ink.
    private static let onFillLightnessThreshold = 0.62

    /// Ink for content sitting on top of this colour.
    ///
    /// Deliberately a rule over the fill's own lightness rather than a table
    /// keyed by accent: a fifth accent added later gets the right answer
    /// without anyone remembering to extend a lookup.
    var onFillInk: Color {
        lightness > Self.onFillLightnessThreshold
            ? Color(hex: 0x141414)
            : Color(hex: 0xf6fbfb)
    }
}

// MARK: - Helpers

nonisolated extension ColorScheme {

    /// Picks one of two values for this scheme. Anything Apple adds beyond
    /// light and dark falls back to light, which is what SwiftUI itself does.
    func pick<Value>(light: Value, dark: Value) -> Value {
        self == .dark ? dark : light
    }
}

nonisolated extension Color {

    /// A colour from a six-digit sRGB hex literal. Only the design layer calls
    /// this; feature code never sees a raw number.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}
