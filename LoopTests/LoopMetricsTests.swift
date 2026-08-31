import SwiftUI
import Testing

@testable import Loop

// MARK: - Metrics

/// The export renders iPad at exactly 1.15 × iPhone. These tests hold the
/// numbers the HTML was drawn with, so a future edit to the metrics cannot
/// quietly move the layout off the design.
@Suite("Metrics")
struct LoopMetricsTests {

    @Test("The page padding picks the right side of each branch")
    func paddingBranches() {
        let portrait = LoopMetrics(isPad: false, isLandscape: false).pagePadding
        let landscape = LoopMetrics(isPad: false, isLandscape: true).pagePadding

        // Landscape is shallower top and bottom and wider at the sides — the
        // export renders 48/28/32 against 32/40/24. The notes say the
        // landscape sides are 28; the export draws 40 and the export is what
        // was drawn, so the sides have to come out wider, not narrower.
        #expect(landscape.top < portrait.top)
        #expect(landscape.bottom < portrait.bottom)
        #expect(landscape.leading > portrait.leading)

        // The sides are symmetric in every layout.
        #expect(portrait.leading == portrait.trailing)
        #expect(landscape.leading == landscape.trailing)

        // iPhone portrait is the only layout with the narrow sides; iPad
        // carries the landscape side padding even in portrait.
        let padPortrait = LoopMetrics(isPad: true, isLandscape: false).pagePadding
        #expect(padPortrait.leading == landscape.leading * 1.15)
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

    @Test("Every layout but iPhone portrait holds content to a column")
    func contentColumn() {
        // iPhone portrait is the only one drawn without a column.
        #expect(LoopMetrics(isPad: false, isLandscape: false).contentColumnWidth == nil)

        // iPhone landscape carries max-width:520px through every state. Left
        // unbounded, a control row there draws about 725 pt wide.
        #expect(LoopMetrics(isPad: false, isLandscape: true).contentColumnWidth == 520)

        // iPad draws the same column at the 1.15 factor, in both orientations.
        for isLandscape in [false, true] {
            let column = LoopMetrics(isPad: true, isLandscape: isLandscape).contentColumnWidth
            #expect(column.map { abs($0 - 598) < 0.001 } == true)
        }
    }

    @Test("The active dot is the larger, undimmed one")
    func navigationDots() {
        // The only relationship in the dot row that is not simply a constant
        // repeated: the current page has to read as bigger and brighter.
        let phone = LoopMetrics(isPad: false, isLandscape: false)
        #expect(phone.activeDotSize > phone.inactiveDotSize)
        #expect(LoopMetrics.inactiveDotOpacity < 1)
    }

    @Test("The countdown's idle state closes up in landscape")
    func countdownIdleSpacing() {
        // 26 pt portrait, 14 pt landscape, and both at the iPad factor.
        #expect(LoopMetrics(isPad: false, isLandscape: false).countdownIdleSpacing == 26)
        #expect(LoopMetrics(isPad: false, isLandscape: true).countdownIdleSpacing == 14)
        #expect(abs(LoopMetrics(isPad: true, isLandscape: false).countdownIdleSpacing - 29.9) < 0.001)
        #expect(abs(LoopMetrics(isPad: true, isLandscape: true).countdownIdleSpacing - 16.1) < 0.001)
    }

    @Test("The time block is offset upwards, not downwards")
    func timeBlockOffsetDirection() {
        // A sign flip would move the time 60 pt the wrong way and still pass
        // any test that only compared magnitudes.
        #expect(LoopMetrics(isPad: false, isLandscape: false).timeBlockOffset < 0)
    }

    @Test("iPad is the iPhone layout at 1.15, everywhere")
    func padScalesEverything() {
        // This is the arithmetic worth testing, and where a mistake would
        // actually hide: one value written at its iPad size by hand, or one
        // that forgot to scale at all.
        let phone = LoopMetrics(isPad: false, isLandscape: true)
        let pad = LoopMetrics(isPad: true, isLandscape: true)
        let factor: CGFloat = 1.15

        let values: [(String, (LoopMetrics) -> CGFloat)] = [
            ("timeBlockSpacing", \.timeBlockSpacing),
            ("timeBlockOffset", \.timeBlockOffset),
            ("countdownIdleSpacing", \.countdownIdleSpacing),
            ("pillSpacing", \.pillSpacing),
            ("pillDotSize", \.pillDotSize),
            ("buttonVerticalPadding", \.buttonVerticalPadding),
            ("controlRowSpacing", \.controlRowSpacing),
            ("hairlineWidth", \.hairlineWidth),
            ("activeDotSize", \.activeDotSize),
            ("inactiveDotSize", \.inactiveDotSize),
            ("dotSpacing", \.dotSpacing),
            ("dotsTopPadding", \.dotsTopPadding),
            ("sliderSpacing", \.sliderSpacing),
            ("sliderTickRowHeight", \.sliderTickRowHeight),
            ("sliderMajorTickHeight", \.sliderMajorTickHeight),
            ("sliderMarkerHeight", \.sliderMarkerHeight),
            ("stepperDiameter", \.stepperDiameter),
            ("stepperSpacing", \.stepperSpacing),
            ("accentRowRadius", \.accentRowRadius),
            ("accentSwatchSize", \.accentSwatchSize),
        ]

        for (name, value) in values {
            #expect(
                abs(value(pad) - value(phone) * factor) < 0.001,
                "\(name) does not scale by 1.15"
            )
        }
    }

    @Test("The iPad values the export actually renders")
    func padSpotValues() {
        // Spot checks straight off the iPad export, so the ratio above cannot
        // be right while the base it scales is wrong.
        let pad = LoopMetrics(isPad: true, isLandscape: false)
        #expect(abs(pad.activeDotSize - 8.05) < 0.001)
        #expect(abs(pad.inactiveDotSize - 6.9) < 0.001)
        #expect(abs(pad.timeBlockOffset - -34.5) < 0.001)
        #expect(abs(pad.timeBlockSpacing - 16.1) < 0.001)
        #expect(abs(pad.pillPadding.top - 10.35) < 0.001)
        #expect(abs(pad.pillPadding.leading - 18.4) < 0.001)
        #expect(abs(pad.buttonVerticalPadding - 17.25) < 0.001)
    }
}
