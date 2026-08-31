import Foundation
import Testing

@testable import Loop

// MARK: - Typography

/// The export writes letter-spacing in `em` and SwiftUI's `tracking` takes
/// points. The conversion happens once, inside the design layer; these tests
/// are what keeps it there and correct.
@Suite("Typography")
struct LoopTypographyTests {

    private let phone = LoopTypography(scale: 1, isLandscape: false)
    private let phoneLandscape = LoopTypography(scale: 1, isLandscape: true)
    private let pad = LoopTypography(scale: 1.15, isLandscape: false)
    private let padLandscape = LoopTypography(scale: 1.15, isLandscape: true)

    @Test("Tracking is converted from em to points against the role's own size")
    func trackingIsInPoints() {
        // 11 pt at .14em is 1.54 pt, not 0.14.
        #expect(abs(phone.statusPill.tracking - 1.54) < 0.001)
        #expect(abs(phone.secondaryLine.tracking - 11 * 0.18) < 0.001)
        #expect(abs(phone.sectionHeading.tracking - 11 * 0.2) < 0.001)
        #expect(abs(phone.button.tracking - 12 * 0.12) < 0.001)
        #expect(abs(phone.settingsRow.tracking - 14 * -0.01) < 0.001)
        #expect(abs(phone.footer.tracking - 10 * 0.16) < 0.001)
    }

    @Test("Tracking scales with the size on iPad, because em does")
    func trackingScales() {
        #expect(abs(pad.statusPill.tracking - 11 * 1.15 * 0.14) < 0.001)
    }

    @Test("The big time shrinks by 5 over the character count")
    func bigTimeAutoScale() {
        // Every one of these sizes is drawn in the export. "25:00" is the
        // reference and is not scaled; "09:41:07" is 8 characters and comes
        // out at 65 pt on an iPhone in portrait.
        #expect(abs(phone.bigTime(characterCount: 5).size - 104) < 0.001)
        #expect(abs(phone.bigTime(characterCount: 8).size - 65) < 0.001)

        // Landscape starts from 84 and lands on 52.5.
        #expect(abs(phoneLandscape.bigTime(characterCount: 5).size - 84) < 0.001)
        #expect(abs(phoneLandscape.bigTime(characterCount: 8).size - 52.5) < 0.001)

        // iPad: 104 × 1.15 = 119.6 in portrait, 74.75 with seconds, and
        // 84 × 1.15 × 5/8 = 60.375 in landscape.
        #expect(abs(pad.bigTime(characterCount: 5).size - 119.6) < 0.001)
        #expect(abs(pad.bigTime(characterCount: 8).size - 74.75) < 0.001)
        #expect(abs(padLandscape.bigTime(characterCount: 8).size - 60.375) < 0.001)
    }

    @Test("A string shorter than the reference does not grow the type")
    func bigTimeNeverGrows() {
        // The factor is capped at 1, so "0:00" stays at the base size rather
        // than scaling up to fill the width.
        #expect(phone.bigTime(characterCount: 4).size == 104)
        #expect(phone.bigTime(characterCount: 1).size == 104)
    }

    @Test("Roles carry their own opacity and casing")
    func rolesCarryTheirOwnTreatment() {
        #expect(phone.secondaryLine.opacity == 0.62)
        #expect(phone.sectionHeading.opacity == 0.62)
        #expect(phone.footer.opacity == 0.4)
        #expect(phone.statusPill.isUppercased)
        #expect(phone.button.isUppercased)
        #expect(!phone.settingsRow.isUppercased)
    }
}
