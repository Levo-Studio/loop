import SwiftUI
import Testing
import UIKit

@testable import Loop

// MARK: - Line height

/// The export's `line-height` is well under 1 on the two large roles, against a
/// natural leading of roughly 1.3. Whether it is applied decides where the time
/// sits on the page, and it is invisible in the source of any screen — so it is
/// measured here, on the rendered view, rather than asserted on the property
/// that feeds it. A `loopTextStyle` that stopped applying the line height would
/// still pass a test that only read `style.lineHeight`.
@MainActor
@Suite("Line height")
struct LoopLineHeightTests {

    /// The height SwiftUI actually lays the view out at.
    private func measuredHeight(_ view: some View) -> CGFloat {
        let controller = UIHostingController(rootView: view)
        let unbounded = CGFloat.greatestFiniteMagnitude
        return controller.sizeThatFits(in: CGSize(width: unbounded, height: unbounded)).height
    }

    private let typography = LoopTypography(scale: 1, isLandscape: false)

    @Test("The big time is laid out at .82 of its point size")
    func bigTimeLineHeight() {
        let style = typography.bigTime(characterCount: 5)
        #expect(abs(style.size - 104) < 0.001)

        let height = measuredHeight(Text(verbatim: "25:00").loopTextStyle(style))
        #expect(abs(height - 104 * 0.82) < 0.5)
    }

    @Test("The countdown preview is laid out at .86 of its point size")
    func countdownPreviewLineHeight() {
        let style = typography.countdownPreview
        let height = measuredHeight(Text(verbatim: "25:00").loopTextStyle(style))
        #expect(abs(height - style.size * 0.86) < 0.5)
    }

    @Test("The line height genuinely shortens the box the font would draw")
    func lineHeightIsNotTheNaturalLeading() {
        // The counter-check. Without this the test above would still pass if
        // IBM Plex Mono happened to lead at .82, and it does not — it leads at
        // roughly 1.3, so the styled box is far shorter than the bare one.
        let style = typography.bigTime(characterCount: 5)
        let styled = measuredHeight(Text(verbatim: "25:00").loopTextStyle(style))
        let bare = measuredHeight(Text(verbatim: "25:00").font(style.font))

        #expect(bare > styled + 20)
    }

    @Test("A role without a line height keeps the font's own leading")
    func rolesWithoutLineHeightAreUntouched() {
        // Only the two large roles carry one. A frame applied to the others
        // would clamp labels that are allowed to lead naturally.
        #expect(typography.statusPill.lineHeight == nil)
        #expect(typography.secondaryLine.lineHeight == nil)
        #expect(typography.button.lineHeight == nil)
        #expect(typography.settingsRow.lineHeight == nil)

        let style = typography.statusPill
        let styled = measuredHeight(Text(verbatim: "CLOCK").loopTextStyle(style))
        let bare = measuredHeight(Text(verbatim: "CLOCK").font(style.font))
        #expect(abs(styled - bare) < 0.5)
    }
}
