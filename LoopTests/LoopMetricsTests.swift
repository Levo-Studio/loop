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

    /// Every scalar on `LoopMetrics`, by name. Both the idiom test and the
    /// orientation test walk this list, so a value added without a thought for
    /// either axis is covered by both the moment it appears here.
    private static let scalars: [(String, (LoopMetrics) -> CGFloat)] = [
        ("timeBlockSpacing", \.timeBlockSpacing),
        ("timeBlockOffset", \.timeBlockOffset),
        ("countdownIdleSpacing", \.countdownIdleSpacing),
        ("intervalSetupSpacing", \.intervalSetupSpacing),
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
        ("sliderScaleTopPadding", \.sliderScaleTopPadding),
        ("sliderTickRowHeight", \.sliderTickRowHeight),
        ("sliderMinuteTickWidth", \.sliderMinuteTickWidth),
        ("sliderMinuteTickHeight", \.sliderMinuteTickHeight),
        ("sliderMajorTickWidth", \.sliderMajorTickWidth),
        ("sliderMajorTickHeight", \.sliderMajorTickHeight),
        ("sliderNumberRowHeight", \.sliderNumberRowHeight),
        ("sliderNumberRowTopPadding", \.sliderNumberRowTopPadding),
        ("sliderMarkerWidth", \.sliderMarkerWidth),
        ("sliderMarkerHeight", \.sliderMarkerHeight),
        ("stepperDiameter", \.stepperDiameter),
        ("stepperSpacing", \.stepperSpacing),
        ("stepperValueWidth", \.stepperValueWidth),
        ("settingsSectionSpacing", \.settingsSectionSpacing),
        ("settingsRowSpacing", \.settingsRowSpacing),
        ("accentSectionSpacing", \.accentSectionSpacing),
        ("accentListSpacing", \.accentListSpacing),
        ("accentRowSpacing", \.accentRowSpacing),
        ("accentRowRadius", \.accentRowRadius),
        ("accentRowBorderWidth", \.accentRowBorderWidth),
        ("accentSwatchSize", \.accentSwatchSize),
        ("accentSwatchRadius", \.accentSwatchRadius),
        ("toggleKnobSize", \.toggleKnobSize),
        ("toggleKnobInset", \.toggleKnobInset),
    ]

    /// The values the export draws differently in landscape, portrait first.
    ///
    /// Everything on `LoopMetrics` that is not in here is drawn at the same
    /// size in both orientations, and the test below holds it to that — an
    /// orientation variant invented where the export has none fails just as
    /// loudly as one that was missed.
    private static let landscapeVariants: [String: (CGFloat, CGFloat)] = [
        "countdownIdleSpacing": (26, 14),
        "intervalSetupSpacing": (24, 16),
        "sliderTickRowHeight": (19, 16),
        "sliderMinuteTickHeight": (8, 7),
        "sliderMajorTickHeight": (17, 14),
        "sliderMarkerHeight": (30, 26),
    ]

    /// The values the export draws at the same size on both idioms.
    ///
    /// Strokes, not dimensions. A 1 px border is drawn at device resolution
    /// and stays 1 px while the layout around it grows by 1.15. The slider
    /// tick widths look like the same thing and are not — they are drawn
    /// geometry and do scale — which is exactly why this is a list and not a
    /// rule about thin things.
    private static let unscaled: Set<String> = [
        "hairlineWidth",
        "accentRowBorderWidth",
    ]

    @Test("The strokes the export does not scale stay put on iPad")
    func unscaledValues() {
        let phone = LoopMetrics(isPad: false, isLandscape: false)
        let pad = LoopMetrics(isPad: true, isLandscape: false)

        #expect(phone.hairlineWidth == 1)
        #expect(pad.hairlineWidth == 1)
        #expect(phone.accentRowBorderWidth == 1.5)
        #expect(pad.accentRowBorderWidth == 1.5)

        // The near neighbours that do scale, so the two cannot be conflated.
        #expect(abs(pad.sliderMinuteTickWidth - 1.15) < 0.001)
        #expect(abs(pad.sliderMajorTickWidth - 1.725) < 0.001)
    }

    @Test("Only the values the export redraws change with the orientation")
    func orientationVariants() {
        let portrait = LoopMetrics(isPad: false, isLandscape: false)
        let landscape = LoopMetrics(isPad: false, isLandscape: true)

        for (name, value) in Self.scalars {
            if let (expectedPortrait, expectedLandscape) = Self.landscapeVariants[name] {
                #expect(value(portrait) == expectedPortrait, "\(name) portrait")
                #expect(value(landscape) == expectedLandscape, "\(name) landscape")
            } else {
                #expect(
                    value(portrait) == value(landscape),
                    "\(name) changes with the orientation, and the export does not"
                )
            }
        }
    }

    @Test("The landscape variants hold at the iPad factor too")
    func orientationVariantsScale() {
        let portrait = LoopMetrics(isPad: true, isLandscape: false)
        let landscape = LoopMetrics(isPad: true, isLandscape: true)

        for (name, value) in Self.scalars {
            guard let (expectedPortrait, expectedLandscape) = Self.landscapeVariants[name] else { continue }
            #expect(abs(value(portrait) - expectedPortrait * 1.15) < 0.001, "\(name) iPad portrait")
            #expect(abs(value(landscape) - expectedLandscape * 1.15) < 0.001, "\(name) iPad landscape")
        }
    }

    @Test("iPad is the iPhone layout at 1.15, everywhere")
    func padScalesEverything() {
        // This is the arithmetic worth testing, and where a mistake would
        // actually hide: one value written at its iPad size by hand, or one
        // that forgot to scale at all.
        let phone = LoopMetrics(isPad: false, isLandscape: true)
        let pad = LoopMetrics(isPad: true, isLandscape: true)
        let factor: CGFloat = 1.15

        for (name, value) in Self.scalars {
            if Self.unscaled.contains(name) {
                #expect(value(pad) == value(phone), "\(name) should not scale")
            } else {
                #expect(
                    abs(value(pad) - value(phone) * factor) < 0.001,
                    "\(name) does not scale by 1.15"
                )
            }
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
