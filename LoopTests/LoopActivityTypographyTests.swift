import Testing
import UIKit

@testable import Loop

// MARK: - The compact time's reserved width

/// The compact Dynamic Island is the one surface in Loop that has to say how
/// wide a string is before the string exists: iOS draws the digits itself
/// inside the window, so there is nothing for SwiftUI to measure and it asks
/// for a width unrelated to what it prints. That is what stretched the island
/// across the status bar, and these tests are what keeps the reservation both
/// wide enough to hold the digits and narrow enough to still be an island.
@Suite("Compact Dynamic Island time")
struct LoopActivityTypographyTests {

    /// The face the compact time is set in, at its own size.
    private static let font = UIFont(
        name: LoopFonts.Weight.regular.postScriptName,
        size: LoopActivityTypography.compactTime.size
    )

    /// What the string actually takes, with the role's tracking applied — the
    /// same negative value `loopTextStyle` hands to SwiftUI.
    private func drawnWidth(_ text: String) throws -> CGFloat {
        let font = try #require(Self.font)

        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .kern: LoopActivityTypography.compactTime.tracking
            ]
        ).size().width
    }

    @Test("Every string the digits can be fits the room reserved for it")
    func theReservationHoldsTheDigits() throws {
        let cases = [
            (characters: 5, text: "59:59"),
            (characters: 7, text: "1:29:59"),
            (characters: 8, text: "30:00:00")
        ]

        for (characters, text) in cases {
            let reserved = LoopActivityTypography.compactTimeWidth(characters: characters)
            #expect(reserved >= (try drawnWidth(text)))
        }
    }

    /// Rounding, in points over a whole string. The reservation is arithmetic
    /// on a nominal advance and the drawn width comes back out of Core Text,
    /// so the two are allowed to disagree by a fraction of a point and by
    /// nothing more.
    private static let measurementTolerance: CGFloat = 0.1

    @Test("The reservation is the digits' width, not a slot the island has to stretch for")
    func theReservationIsNoWiderThanTheDigits() throws {
        // The reservation is the font's own advance times the size; the drawn
        // string is that same advance with the role's negative tracking taken
        // off each character. So the whole of the slack the reservation may
        // carry is the tracking it deliberately does not subtract, and the
        // bound is that amount rather than a round number that happens to sit
        // above it. Anything past it is an advance wider than the face
        // actually has — width the island would be padded out with.
        let tracking = abs(LoopActivityTypography.compactTime.tracking)

        for characters in [5, 7, 8] {
            let reserved = LoopActivityTypography.compactTimeWidth(characters: characters)
            let drawn = try drawnWidth(String(repeating: "0", count: characters))
            let slack = reserved - drawn

            #expect(slack <= CGFloat(characters) * tracking + Self.measurementTolerance)
        }
    }
}
