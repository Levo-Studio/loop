import SwiftUI
import Testing

@testable import Loop

// MARK: - Conversion

/// The accents are written in OKLCH because light and dark share one hue, and
/// the on-fill rule reads the lightness directly. Both properties only survive
/// if the conversion to sRGB is the real one, so these are the numbers the
/// design export asks for.
///
/// The expected values were derived on a different path from the one under
/// test: OKLab → LMS → XYZ (D65) → linear sRGB → sRGB, rather than the single
/// combined OKLab → linear sRGB matrix the app uses. A transcription slip in
/// either matrix therefore shows up as a mismatch instead of cancelling out.
@Suite("OKLCH conversion")
struct OKLCHConversionTests {

    /// Three decimals is finer than an 8-bit channel, so a value that passes
    /// here rounds to the same byte the design tool produced.
    private static let tolerance = 0.001

    private func expect(
        _ colour: OKLCH,
        red: Double,
        green: Double,
        blue: Double,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let components = colour.sRGBComponents
        #expect(abs(components.red - red) < Self.tolerance, sourceLocation: sourceLocation)
        #expect(abs(components.green - green) < Self.tolerance, sourceLocation: sourceLocation)
        #expect(abs(components.blue - blue) < Self.tolerance, sourceLocation: sourceLocation)
    }

    @Test("Petrol resolves to the sRGB the export was drawn in")
    func petrol() {
        expect(LoopAccent.petrol.fill(.light), red: 0.074, green: 0.503, blue: 0.543)
        expect(LoopAccent.petrol.fill(.dark), red: 0, green: 0.327, blue: 0.361)
        expect(LoopAccent.petrol.marker(.light), red: 0.074, green: 0.503, blue: 0.543)
        expect(LoopAccent.petrol.marker(.dark), red: 0.224, green: 0.666, blue: 0.712)
    }

    @Test("Amber resolves to the sRGB the export was drawn in")
    func amber() {
        expect(LoopAccent.amber.fill(.light), red: 0.834, green: 0.591, blue: 0.255)
        expect(LoopAccent.amber.fill(.dark), red: 0.501, green: 0.324, blue: 0.027)
        expect(LoopAccent.amber.marker(.light), red: 0.834, green: 0.591, blue: 0.255)
        expect(LoopAccent.amber.marker(.dark), red: 0.873, green: 0.627, blue: 0.295)
    }

    @Test("Lilac resolves to the sRGB the export was drawn in")
    func lilac() {
        expect(LoopAccent.lilac.fill(.light), red: 0.537, green: 0.414, blue: 0.675)
        expect(LoopAccent.lilac.fill(.dark), red: 0.337, green: 0.237, blue: 0.444)
        expect(LoopAccent.lilac.marker(.light), red: 0.537, green: 0.414, blue: 0.675)
        expect(LoopAccent.lilac.marker(.dark), red: 0.62, green: 0.495, blue: 0.763)
    }

    @Test("Graphite resolves to the sRGB the export was drawn in")
    func graphite() {
        expect(LoopAccent.graphite.fill(.light), red: 0.207, green: 0.221, blue: 0.235)
        expect(LoopAccent.graphite.fill(.dark), red: 0.607, green: 0.623, blue: 0.64)
    }

    @Test("Graphite's marker is its fill, in both schemes")
    func graphiteMarkerFollowsFill() {
        #expect(LoopAccent.graphite.marker(.light) == LoopAccent.graphite.fill(.light))
        #expect(LoopAccent.graphite.marker(.dark) == LoopAccent.graphite.fill(.dark))
    }

    @Test("Petrol's dark fill leaves the sRGB gamut and is clamped, not wrapped")
    func outOfGamutClamps() {
        // Red comes out negative before encoding. A missing clamp would show up
        // as a channel far from zero rather than as a slightly wrong colour,
        // so this is worth its own case.
        let components = LoopAccent.petrol.fill(.dark).sRGBComponents
        #expect(components.red == 0)
    }
}

// MARK: - On-fill rule

@Suite("On-fill ink")
struct OnFillInkTests {

    @Test("A light fill takes dark ink and a dark fill takes light ink")
    func ruleFollowsLightness() {
        // Amber light (0.72) and graphite dark (0.70) are the two fills above
        // the threshold in the current palette.
        #expect(LoopAccent.amber.fill(.light).onFillInk == Color(hex: 0x141414))
        #expect(LoopAccent.graphite.fill(.dark).onFillInk == Color(hex: 0x141414))

        #expect(LoopAccent.petrol.fill(.light).onFillInk == Color(hex: 0xf6fbfb))
        #expect(LoopAccent.petrol.fill(.dark).onFillInk == Color(hex: 0xf6fbfb))
        #expect(LoopAccent.amber.fill(.dark).onFillInk == Color(hex: 0xf6fbfb))
        #expect(LoopAccent.lilac.fill(.light).onFillInk == Color(hex: 0xf6fbfb))
        #expect(LoopAccent.lilac.fill(.dark).onFillInk == Color(hex: 0xf6fbfb))
        #expect(LoopAccent.graphite.fill(.light).onFillInk == Color(hex: 0xf6fbfb))
    }

    @Test("The rule holds for an accent nobody has added yet")
    func ruleHoldsEitherSideOfTheThreshold() {
        // The point of a rule over a lookup table: a hue and a chroma that
        // appear nowhere in the palette still get the right answer, and the
        // switch happens exactly at 0.62.
        #expect(OKLCH(0.63, 0.2, 140).onFillInk == Color(hex: 0x141414))
        #expect(OKLCH(0.62, 0.2, 140).onFillInk == Color(hex: 0xf6fbfb))
        #expect(OKLCH(0.61, 0.2, 140).onFillInk == Color(hex: 0xf6fbfb))
    }
}
