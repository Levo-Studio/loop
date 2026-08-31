import SwiftUI
import Testing

@testable import Loop

// MARK: - Metrics

/// The export renders iPad at exactly 1.15 × iPhone. These tests hold the
/// numbers the HTML was drawn with, so a future edit to the metrics cannot
/// quietly move the layout off the design.
@Suite("Metrics")
struct LoopMetricsTests {

    @Test("iPhone portrait pads 48 / 28 / 32")
    func phonePortraitPadding() {
        let padding = LoopMetrics(isPad: false, isLandscape: false).pagePadding
        #expect(padding.top == 48)
        #expect(padding.leading == 28)
        #expect(padding.bottom == 32)
        #expect(padding.trailing == 28)
    }

    @Test("iPhone landscape pads 32 / 40 / 24")
    func phoneLandscapePadding() {
        // The written notes say 32/28/24 here; the export renders 32/40/24 and
        // the export is what was drawn.
        let padding = LoopMetrics(isPad: false, isLandscape: true).pagePadding
        #expect(padding.top == 32)
        #expect(padding.leading == 40)
        #expect(padding.bottom == 24)
    }

    @Test("iPad scales the page padding by 1.15")
    func padPadding() {
        let portrait = LoopMetrics(isPad: true, isLandscape: false).pagePadding
        #expect(abs(portrait.top - 55.2) < 0.001)
        #expect(abs(portrait.leading - 46) < 0.001)
        #expect(abs(portrait.bottom - 36.8) < 0.001)

        let landscape = LoopMetrics(isPad: true, isLandscape: true).pagePadding
        #expect(abs(landscape.top - 36.8) < 0.001)
        #expect(abs(landscape.leading - 46) < 0.001)
        #expect(abs(landscape.bottom - 27.6) < 0.001)
    }

    @Test("The content column is an iPad idea only")
    func contentColumn() {
        #expect(LoopMetrics(isPad: false, isLandscape: false).contentColumnWidth == nil)

        // 520 pt in the notes, drawn at 598 px because the whole iPad layout
        // carries the 1.15 factor.
        let column = LoopMetrics(isPad: true, isLandscape: false).contentColumnWidth
        #expect(column.map { abs($0 - 598) < 0.001 } == true)
    }

    @Test("The navigation dots keep their drawn sizes")
    func navigationDots() {
        let phone = LoopMetrics(isPad: false, isLandscape: false)
        #expect(phone.activeDotSize == 7)
        #expect(phone.inactiveDotSize == 6)
        #expect(phone.dotSpacing == 9)
        #expect(phone.dotsTopPadding == 16)
        #expect(LoopMetrics.inactiveDotOpacity == 0.3)

        let pad = LoopMetrics(isPad: true, isLandscape: false)
        #expect(abs(pad.activeDotSize - 8.05) < 0.001)
        #expect(abs(pad.inactiveDotSize - 6.9) < 0.001)
    }

    @Test("The time block sits 30 pt high of centre")
    func timeBlock() {
        let phone = LoopMetrics(isPad: false, isLandscape: false)
        #expect(phone.timeBlockOffset == -30)
        #expect(phone.timeBlockSpacing == 14)

        let pad = LoopMetrics(isPad: true, isLandscape: false)
        #expect(abs(pad.timeBlockOffset - -34.5) < 0.001)
        #expect(abs(pad.timeBlockSpacing - 16.1) < 0.001)
    }
}
