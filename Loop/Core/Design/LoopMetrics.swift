import SwiftUI

// MARK: - Metrics

/// Every distance, size and radius the app draws, resolved for one idiom and
/// one orientation.
///
/// The export renders iPad at exactly 1.15 × the iPhone values — 55.2 pt of top
/// padding is 48 × 1.15, a 6.9 pt navigation dot is 6 × 1.15, the 520 pt content
/// column is drawn at 598 px. So every number below is written once at its
/// iPhone value and multiplied by `scale`; nothing is a second table that could
/// drift from the first.
nonisolated struct LoopMetrics: Equatable, Sendable {

    /// 1.0 on iPhone, 1.15 on iPad.
    let scale: CGFloat

    /// Whether the window is wider than it is tall.
    let isLandscape: Bool

    /// Whether the app runs on iPad. It changes the side padding and adds the
    /// centred content column; it is not the same question as `scale`.
    let isPad: Bool

    // MARK: - Idiom

    /// The iPad type and layout scale from the export.
    private static let padScale: CGFloat = 1.15

    init(isPad: Bool, isLandscape: Bool) {
        self.scale = isPad ? Self.padScale : 1
        self.isLandscape = isLandscape
        self.isPad = isPad
    }

    /// Scales an iPhone-portrait value to the current idiom.
    func scaled(_ value: CGFloat) -> CGFloat { value * scale }

    // MARK: - Page

    /// The page padding: 48/28/32 on iPhone portrait, 32/40/24 in landscape.
    ///
    /// The written notes say landscape is 32/28/24; the export renders 32/40/24
    /// and the export is what was actually drawn, so the wider side padding is
    /// the one implemented. iPad keeps the landscape side padding in portrait
    /// too — its portrait padding is 55.2/46/36.8, which is 48/40/32 × 1.15.
    var pagePadding: EdgeInsets {
        let horizontal: CGFloat = (isPad || isLandscape) ? 40 : 28
        return EdgeInsets(
            top: scaled(isLandscape ? 32 : 48),
            leading: scaled(horizontal),
            bottom: scaled(isLandscape ? 24 : 32),
            trailing: scaled(horizontal)
        )
    }

    /// The width the content is held to, or `nil` where it simply fills the
    /// page between its paddings.
    ///
    /// One rule, not an iPad special case. The column is `520 × scale`
    /// wherever the layout is wider than iPhone portrait: the export carries
    /// `max-width:520px` on the control rows, the sliders and the idle preview
    /// through every iPhone landscape state, and `max-width:598px` — the same
    /// 520 at the iPad factor — through both iPad orientations. iPhone
    /// portrait is the only layout narrow enough not to need it, and it has
    /// none.
    ///
    /// It also settles the landscape side padding. A notched iPhone reports a
    /// side inset well beyond the drawn 40 pt, but the column binds first, so
    /// the row lands where it was drawn rather than where the inset would put
    /// it.
    var contentColumnWidth: CGFloat? {
        isPad || isLandscape ? scaled(520) : nil
    }

    // MARK: - Time block

    /// The gap between the big time and the line under it.
    var timeBlockSpacing: CGFloat { scaled(14) }

    /// The gap between the countdown's idle preview and the scale under it.
    ///
    /// Not `timeBlockSpacing`: the idle state is its own layout in the export,
    /// centred without the −30 pt offset, and it closes up in landscape where
    /// the preview and the slider have to share a shallow page.
    var countdownIdleSpacing: CGFloat { scaled(isLandscape ? 14 : 26) }

    /// The gap between the two scales, the divider, the round stepper and the
    /// total on the interval setup page.
    ///
    /// Closes up in landscape like the countdown's idle state does, and for
    /// the same reason — this page carries the most content of the five.
    var intervalSetupSpacing: CGFloat { scaled(isLandscape ? 16 : 24) }

    /// The time block sits 30 pt above the centre of the space it is given.
    /// Optical centring: the block is read against the page as a whole, and the
    /// controls at the bottom pull the perceived centre downwards.
    var timeBlockOffset: CGFloat { scaled(-30) }

    // MARK: - Status pill

    var pillPadding: EdgeInsets {
        EdgeInsets(top: scaled(9), leading: scaled(16), bottom: scaled(9), trailing: scaled(16))
    }

    /// The gap between the pill's dot and its label, and between its two label
    /// parts.
    var pillSpacing: CGFloat { scaled(10) }

    /// The accent dot at the head of the pill.
    var pillDotSize: CGFloat { scaled(6) }

    // MARK: - Controls

    /// The vertical padding inside a button — roughly a 50 pt tall control.
    var buttonVerticalPadding: CGFloat { scaled(15) }

    /// The gap between the two buttons of a control row.
    var controlRowSpacing: CGFloat { scaled(10) }

    /// The width of a secondary button's border, a divider line and a stepper
    /// circle.
    ///
    /// **Not scaled.** The export draws these at 1 px on iPad exactly as on
    /// iPhone, while everything around them grows by 1.15 — a hairline is a
    /// stroke at device resolution, not a dimension of the layout. The slider
    /// ticks are the opposite case and do scale: they are drawn geometry that
    /// happens to be thin, not a border.
    var hairlineWidth: CGFloat { 1 }

    /// The opacity a disabled control drops to. It stays in place rather than
    /// disappearing, so the layout does not move when a button becomes legal.
    static let disabledOpacity: Double = 0.45

    // MARK: - Navigation dots

    var activeDotSize: CGFloat { scaled(7) }
    var inactiveDotSize: CGFloat { scaled(6) }
    var dotSpacing: CGFloat { scaled(9) }
    var dotsTopPadding: CGFloat { scaled(16) }

    /// The opacity of a dot that is not the current page.
    static let inactiveDotOpacity: Double = 0.3

    // MARK: - Scale slider

    /// The gap between a slider's header row and its scale.
    var sliderSpacing: CGFloat { scaled(7) }

    /// The space above the ticks that the marker reaches up into.
    var sliderScaleTopPadding: CGFloat { scaled(5) }

    /// The height of the tick row. Ticks are bottom-aligned inside it.
    ///
    /// The whole bar is shorter in landscape — 16/7/14/26 against 19/8/17/30,
    /// each a clean base at the 1.15 factor on iPad. A shallow page has to fit
    /// a preview, a scale and a control row, and the scale is what gives.
    /// The widths do not change, and neither does the number row beneath.
    var sliderTickRowHeight: CGFloat { scaled(isLandscape ? 16 : 19) }

    var sliderMinuteTickWidth: CGFloat { scaled(1) }
    var sliderMinuteTickHeight: CGFloat { scaled(isLandscape ? 7 : 8) }
    var sliderMajorTickWidth: CGFloat { scaled(1.5) }
    var sliderMajorTickHeight: CGFloat { scaled(isLandscape ? 14 : 17) }

    static let sliderMinuteTickOpacity: Double = 0.25
    static let sliderMajorTickOpacity: Double = 0.55

    /// A taller tick every five minutes.
    static let sliderMajorTickInterval = 5

    /// How often a number is printed under the scale, in minutes.
    ///
    /// Two values, because the long scales and the short one need different
    /// densities. The countdown's duration runs to thirty hours and the
    /// interval's focus block to eight, so both are numbered every fifteen
    /// minutes — 0/15/30/45 through the first hour, `h:mm` from there. The
    /// break runs to two hours and is numbered every ten, which is the density
    /// a value usually set between three and fifteen minutes wants.
    ///
    /// Both are drawn identically in all four layouts, so unlike nearly
    /// everything else here they take neither the idiom factor nor a landscape
    /// variant: they count minutes, and a minute is not a length. The pitch
    /// between two minutes is the thing that scales, and that is
    /// `sliderMinutePitch(width:)`.
    ///
    /// The **ranges** these subdivide belong to the engine, in
    /// `LoopTimerLimits`, and so does which values on them can be picked. How
    /// far a scale runs and where it stops are rules about the timer; how often
    /// it is labelled is a rule about the drawing.
    static let durationNumberInterval = 15
    static let breakNumberInterval = 10

    var sliderNumberRowHeight: CGFloat { scaled(15) }
    var sliderNumberRowTopPadding: CGFloat { scaled(3) }

    var sliderMarkerWidth: CGFloat { scaled(3) }
    var sliderMarkerHeight: CGFloat { scaled(isLandscape ? 26 : 30) }

    /// How many tick slots the export lays across the width of a scale.
    ///
    /// The countdown's duration scale is drawn as 0…60 in sixty-one equal
    /// `flex:1` slots spanning the content width, so a minute is the width over
    /// sixty-one. This is the one piece of the scale's geometry that the
    /// scrolling version cannot read straight off the export: a scale running
    /// to thirty hours has no "across the width" left to divide by, so the
    /// density is fixed here at what was drawn and the width decides how much
    /// of the scale is visible instead.
    ///
    /// Deriving the pitch from the width rather than from `scaled(_:)` also
    /// keeps every layout matching the export by itself — the iPad column is
    /// `520 × 1.15`, so its ticks come out 1.15 apart without a second rule.
    static let sliderTickSlotsAcrossWidth = 61

    /// The distance between two adjacent minutes on a scale of a given width.
    static func sliderMinutePitch(width: CGFloat) -> CGFloat {
        width / CGFloat(sliderTickSlotsAcrossWidth)
    }

    // MARK: - Break headline

    /// The gap between the interval break's `BREAK` headline and the time block
    /// under it.
    ///
    /// The headline came after the export, so there is no drawn gap for it.
    /// It takes `timeBlockSpacing` — the drawn distance from the big time to
    /// the line beneath it — so the two things flanking the time sit the same
    /// distance from it, which is what makes the block read as one.
    var breakHeadlineSpacing: CGFloat { timeBlockSpacing }

    // MARK: - Stepper

    var stepperDiameter: CGFloat { scaled(29) }
    var stepperSpacing: CGFloat { scaled(13) }

    /// The minimum width of the stepper's value, so the row does not shift when
    /// the number gains a digit.
    var stepperValueWidth: CGFloat { scaled(44) }

    // MARK: - Settings

    /// The gaps down the settings column: between its sections, between the
    /// seconds row and the divider under it, and between the accent heading
    /// and the list.
    ///
    /// The landscape values are **derived, not drawn.** The export has no
    /// landscape settings state at all — both files show Settings only in
    /// their portrait section — so unlike every other landscape variant here
    /// there is no ground truth to check against. But "no ground truth" could
    /// not stay resolved to the portrait values, because they do not fit: the
    /// column is 390.6 pt of content against a 346 pt box on a 402 pt
    /// landscape iPhone, so the navigation dots landed 45 pt past the bottom
    /// of the page, under the home indicator.
    ///
    /// Only 116 pt of that height is gap; the other 274.6 pt is text, the
    /// toggle, four accent rows, the divider, the footer and the dots, none of
    /// which this can touch. Fitting 116 pt of gap into the 71.4 pt that is
    /// left needs a factor of 0.616 or under.
    ///
    /// The export offers two portrait→landscape precedents for a column that
    /// has to fit a shallow page: the interval setup closes 24 → 16, a third
    /// off, and the countdown's idle state closes 26 → 14, closer to a half.
    /// A third off is **not** enough here — it leaves the column 5.9 pt over
    /// the box, still overflowing. So these follow the countdown's ratio,
    /// which lands 8.4 pt inside it.
    ///
    /// That slack is thin, and it is thin at exactly one height. A landscape
    /// iPhone shorter than this one would overflow again, and the honest fix
    /// for that is a scrolling column — which is a layout the export never
    /// drew and therefore the owner's call, not this file's.
    var settingsSectionSpacing: CGFloat { scaled(isLandscape ? 15 : 28) }
    var settingsRowSpacing: CGFloat { scaled(isLandscape ? 8 : 14) }
    var accentSectionSpacing: CGFloat { scaled(isLandscape ? 7 : 13) }

    /// The gap between two accent rows.
    var accentListSpacing: CGFloat { scaled(isLandscape ? 6 : 11) }

    /// The gap between a swatch, its name and the active marker. Horizontal,
    /// so the shallow page does not squeeze it.
    var accentRowSpacing: CGFloat { scaled(12) }

    /// The seconds toggle: a 50 × 29 pt track with a 23 pt knob inset by 3 pt.
    /// The knob is drawn in the page background rather than in an ink, so it
    /// reads as a hole in the accent rather than as a dot on top of it.
    var toggleSize: CGSize { CGSize(width: scaled(50), height: scaled(29)) }
    var toggleKnobSize: CGFloat { scaled(23) }
    var toggleKnobInset: CGFloat { scaled(3) }

    /// The radius of an accent row in the settings list.
    var accentRowRadius: CGFloat { scaled(13) }

    var accentRowPadding: EdgeInsets {
        EdgeInsets(top: scaled(11), leading: scaled(13), bottom: scaled(11), trailing: scaled(13))
    }

    /// The border on **every** accent row, selected or not.
    ///
    /// All four rows carry a 1.5 pt border in the export. Only the colour
    /// changes: the selected row draws it in the accent's marker tone over the
    /// `chip` background, the other three in `hair` over nothing. Drawing the
    /// inactive rows at `hairlineWidth` instead would shift their content by
    /// half a point and make the list twitch as the selection moves.
    ///
    /// **Not scaled**, for the same reason as `hairlineWidth`: the export
    /// draws 1.5 px on both idioms.
    var accentRowBorderWidth: CGFloat { 1.5 }

    var accentSwatchSize: CGFloat { scaled(20) }
    var accentSwatchRadius: CGFloat { scaled(6) }

    // MARK: - Radii

    /// Buttons and pills are fully round. A radius far larger than the control
    /// clamps to a capsule at any height, which is what the export's `999`
    /// means.
    static let fullRoundRadius: CGFloat = 999
}

// MARK: - Environment

extension EnvironmentValues {

    /// The metrics for the current idiom and orientation. `RootShell` puts the
    /// real value in; the default keeps previews of single components working.
    @Entry var loopMetrics = LoopMetrics(isPad: false, isLandscape: false)

    /// The window's safe area insets, captured by `RootShell` before the pages
    /// go edge to edge.
    ///
    /// The pages have to bleed into the safe area — the rising fill is flush to
    /// the physical bottom edge, and a fill that stopped above the home
    /// indicator would not be the design. So the shell reads the insets once
    /// and passes them down, and the layout adds them back where content, not
    /// colour, is placed.
    @Entry var loopSafeAreaInsets = EdgeInsets()
}
