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
