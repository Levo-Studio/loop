import Testing
import UIKit

@testable import Loop

// MARK: - Fonts

/// `Font.custom` falls back to the system font when a name does not resolve, and
/// it does so silently. The whole design is set in IBM Plex Mono, so a bundling
/// or registration mistake would ship as "the app looks slightly wrong" and
/// nothing else. These tests make that failure loud.
@Suite("Bundled fonts")
struct LoopFontsTests {

    private static let familyName = "IBM Plex Mono"

    @Test("The family is registered with the app")
    func familyIsPresent() {
        #expect(UIFont.familyNames.contains(Self.familyName))
    }

    @Test("Every weight the design uses resolves to a real face")
    func everyWeightResolves() {
        let available = Set(UIFont.fontNames(forFamilyName: Self.familyName))
        #expect(!available.isEmpty)

        for weight in [LoopFonts.Weight.light, .regular, .medium] {
            #expect(available.contains(weight.postScriptName))

            // Registration is one half; UIFont actually returning that face is
            // the other. Asking for a name iOS does not know hands back the
            // system font under its own name, which this catches.
            let font = UIFont(name: weight.postScriptName, size: 12)
            #expect(font?.fontName == weight.postScriptName)
        }
    }

    /// `LoopFonts.advanceEm` is what the compact Dynamic Island reserves room
    /// with, and it reserves it for digits iOS has not drawn yet. Nothing at
    /// runtime would notice the constant drifting from the face — the island
    /// would simply start clipping a digit or padding itself out — so the two
    /// are held together here.
    @Test("One glyph is as wide as the layout is told it is, in every weight")
    func theAdvanceMatchesTheFace() throws {
        let size: CGFloat = 100

        for weight in [LoopFonts.Weight.light, .regular, .medium] {
            let font = try #require(UIFont(name: weight.postScriptName, size: size))

            // Monospaced, so a digit, a colon and a letter all measure the
            // same — and that is the assumption the reservation rests on.
            for glyph in ["0", ":", "M"] {
                let width = NSAttributedString(string: glyph, attributes: [.font: font]).size().width
                #expect(abs(width - size * LoopFonts.advanceEm) < 0.01)
            }
        }
    }
}
