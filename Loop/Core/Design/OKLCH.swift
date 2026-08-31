import SwiftUI

// MARK: - OKLCH

/// A colour in the OKLCH space, the notation the design export is written in.
///
/// The export gives every accent as `oklch(L C H)` rather than as hex, because
/// light and dark share one hue and differ only in lightness. Converting here —
/// once, with the published matrices — keeps that property intact. Pasting hex
/// approximations instead would quietly break the on-fill rule below, which
/// reads `lightness` and has to stay right for an accent nobody has added yet.
nonisolated struct OKLCH: Equatable, Sendable {

    /// Perceptual lightness, 0 (black) to 1 (white).
    let lightness: Double

    /// Chroma. Unbounded in principle; the accents stay below 0.13.
    let chroma: Double

    /// Hue angle in degrees.
    let hue: Double

    init(_ lightness: Double, _ chroma: Double, _ hue: Double) {
        self.lightness = lightness
        self.chroma = chroma
        self.hue = hue
    }

    // MARK: - Conversion

    /// The colour as gamma-encoded sRGB components, each clamped to 0…1.
    ///
    /// OKLCH → OKLab is polar to cartesian. OKLab → LMS uses Björn Ottosson's
    /// published matrix, the cube brings LMS out of its cone-response root, and
    /// the second matrix lands in linear sRGB. The transfer function at the end
    /// is the sRGB one, so the result is what `Color(.sRGB, …)` expects.
    ///
    /// Components outside the sRGB gamut are clamped rather than gamut-mapped.
    /// None of the accents leave the gamut, so a clamp is the honest minimum;
    /// a mapping strategy would be untested code.
    var sRGBComponents: (red: Double, green: Double, blue: Double) {
        let radians = hue * .pi / 180
        let a = chroma * cos(radians)
        let b = chroma * sin(radians)

        let lRoot = lightness + 0.3963377774 * a + 0.2158037573 * b
        let mRoot = lightness - 0.1055613458 * a - 0.0638541728 * b
        let sRoot = lightness - 0.0894841775 * a - 1.2914855480 * b

        let l = lRoot * lRoot * lRoot
        let m = mRoot * mRoot * mRoot
        let s = sRoot * sRoot * sRoot

        let linearRed = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let linearGreen = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let linearBlue = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return (Self.encode(linearRed), Self.encode(linearGreen), Self.encode(linearBlue))
    }

    /// The colour as a SwiftUI colour in the sRGB space.
    var color: Color {
        let components = sRGBComponents
        return Color(.sRGB, red: components.red, green: components.green, blue: components.blue)
    }

    /// The sRGB transfer function, clamped to the representable range.
    private static func encode(_ linear: Double) -> Double {
        let encoded = linear <= 0.0031308
            ? 12.92 * linear
            : 1.055 * pow(linear, 1 / 2.4) - 0.055
        return min(1, max(0, encoded))
    }
}
