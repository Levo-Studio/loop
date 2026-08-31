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

    /// The width of a secondary button's border and of a divider line.
    var hairlineWidth: CGFloat { scaled(1) }

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
    var sliderTickRowHeight: CGFloat { scaled(19) }

    var sliderMinuteTickWidth: CGFloat { scaled(1) }
    var sliderMinuteTickHeight: CGFloat { scaled(8) }
    var sliderMajorTickWidth: CGFloat { scaled(1.5) }
    var sliderMajorTickHeight: CGFloat { scaled(17) }

    static let sliderMinuteTickOpacity: Double = 0.25
    static let sliderMajorTickOpacity: Double = 0.55

    /// A taller tick every five minutes.
    static let sliderMajorTickInterval = 5

    var sliderNumberRowHeight: CGFloat { scaled(15) }
    var sliderNumberRowTopPadding: CGFloat { scaled(3) }

    var sliderMarkerWidth: CGFloat { scaled(3) }
    var sliderMarkerHeight: CGFloat { scaled(30) }

    // MARK: - Stepper

    var stepperDiameter: CGFloat { scaled(29) }
    var stepperSpacing: CGFloat { scaled(13) }

    /// The minimum width of the stepper's value, so the row does not shift when
    /// the number gains a digit.
    var stepperValueWidth: CGFloat { scaled(44) }

    // MARK: - Settings

    /// The radius of an accent row in the settings list.
    var accentRowRadius: CGFloat { scaled(13) }

    var accentRowPadding: EdgeInsets {
        EdgeInsets(top: scaled(11), leading: scaled(13), bottom: scaled(11), trailing: scaled(13))
    }

    /// The border on the selected accent row.
    var accentRowBorderWidth: CGFloat { scaled(1.5) }

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
