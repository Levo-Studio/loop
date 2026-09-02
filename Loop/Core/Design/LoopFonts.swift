import SwiftUI

// MARK: - Fonts

/// IBM Plex Mono, bundled with the app.
///
/// The three weights are registered through `UIAppFonts` in `Loop/Info.plist`;
/// the names below are the PostScript names inside the TTFs, which is what
/// `Font.custom` matches on. A typo here fails silently into the system font,
/// which is why `LoopFontsTests` asserts every one of them resolves.
nonisolated enum LoopFonts {

    /// The weights the design uses. 300 for the big time, 500 for labels and
    /// buttons, 400 for everything else — there is no fourth.
    enum Weight {
        case light
        case regular
        case medium

        var postScriptName: String {
            switch self {
            case .light: "IBMPlexMono-Light"
            case .regular: "IBMPlexMono-Regular"
            case .medium: "IBMPlexMono-Medium"
            }
        }
    }

    /// The advance width of one glyph, as a fraction of the point size.
    ///
    /// IBM Plex Mono is monospaced: every glyph — digit, colon, letter —
    /// occupies 600 of the font's 1000 units per em, so a string's width is its
    /// character count times this. It is written down here rather than measured
    /// at a call site because a layout that has to reserve room for a string
    /// nobody has drawn yet — the compact Dynamic Island, whose digits iOS
    /// renders on its own — has no text to measure. `LoopFontsTests` checks it
    /// against the face itself, so a font swap cannot quietly invalidate it.
    static let advanceEm: CGFloat = 0.6

    /// A font at an exact point size.
    ///
    /// `fixedSize` rather than `size`, so Dynamic Type does not rescale it. The
    /// layout is pixel-specified down to the tick marks of the slider and the
    /// two-tone edge that cuts through the time; a text size the design never
    /// saw would break the drawing, not just the reading.
    static func font(_ weight: Weight, size: CGFloat) -> Font {
        .custom(weight.postScriptName, fixedSize: size)
    }
}
