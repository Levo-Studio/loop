import SwiftUI

// MARK: - Settings

/// The switches and the accent list, over a footer. No status pill and no
/// rising area — this page is the only one that is not a timer, so there is no
/// duration to measure and nothing to show progress against.
///
/// Every setting is written straight into `LoopSettings`, which the shell reads
/// to build the palette. That is why the accent list needs no callback and no
/// local copy of the choice: tapping a row changes the one value the whole app
/// resolves its colours from, and every page recolours with it.
struct SettingsScreen: View {

    @Environment(LoopSettings.self) private var settings

    var body: some View {
        // `@Bindable` here rather than inside a slot: the slots are built twice
        // by `FillSurface`, and anything declared in them exists twice. This is
        // a projection of shared state rather than storage, but it belongs
        // outside for the same reason the rest of the state does.
        @Bindable var settings = settings

        return PageScaffold {
            EmptyView()
        } content: {
            SettingsColumn(
                showSeconds: $settings.showSeconds,
                sound: $settings.sound,
                swipeToDismiss: $settings.swipeToDismiss,
                accent: $settings.accent
            )
        } controls: {
            SettingsFooter()
        }
    }
}

// MARK: - Column

/// The heading, the switch block and the accent list.
///
/// A view of its own rather than a `@ViewBuilder` on the screen, because the ink
/// has to be read from inside `PageScaffold`. `FillSurface` puts the tone for
/// the layer it is drawing into the environment, so a screen reading `loopInk`
/// above the scaffold gets the default rather than the running palette — the
/// text would keep the light scheme's ink in dark mode. Every component in the
/// design layer reads it at the leaf for the same reason.
private struct SettingsColumn: View {

    @Binding var showSeconds: Bool
    @Binding var sound: Bool
    @Binding var swipeToDismiss: Bool
    @Binding var accent: LoopAccent

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopInk) private var ink
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The column, and a scrolling copy of it for the heights it does not fit.
    ///
    /// **Why it scrolls at all.** Settings is the one page whose height grows:
    /// every setting the app gains is another row against a page that stays the
    /// same size, and a landscape iPhone has 346 pt of box for it. The three
    /// switches, the divider, the accent list and the footer already come to
    /// 383 pt there. The alternative was to close the landscape gaps further —
    /// `LoopMetrics` already takes them to 0.54 of portrait — but fitting this
    /// column would need roughly 0.22, which is not a tighter design, it is a
    /// squeeze, and the next setting would break it again. The export never
    /// drew a landscape settings state, so nothing here is being contradicted.
    ///
    /// **Why `ViewThatFits` and not a plain `ScrollView`.** A scroll view that
    /// is always there is always scrollable: it bounces, it flashes an
    /// indicator, and it changes how the column is placed in the space it is
    /// given. Portrait — and any landscape with room — has to look exactly as
    /// it did before this was added, and the only way to be sure of that is for
    /// there to be no scroll view in the tree at all. So the plain column is
    /// offered first and taken whenever it fits; the scrolling copy is what is
    /// left when it does not.
    ///
    /// The navigation dots and the page padding are `PageScaffold`'s and are
    /// outside this view, so they stay put while the column moves under them.
    /// The dots are the app's only navigation and must never scroll away.
    ///
    /// - Note: `FillSurface` builds this twice, and a scroll view carries an
    ///   offset of its own that the two copies do not share. It does not show
    ///   here because this page has no duration and so passes `.none`, which
    ///   masks the second copy to a zero-height rectangle — it draws nothing to
    ///   drift. A settings page that ever gained a fill would have to lift the
    ///   scroll position above the scaffold and pass it in, the way `RootShell`
    ///   does with the current page.
    var body: some View {
        ViewThatFits(in: .vertical) {
            column

            ScrollView(.vertical) {
                column
            }
        }
        .foregroundStyle(ink.base)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: metrics.settingsSectionSpacing) {
            Text(LoopStrings.settings)
                .loopTextStyle(typography.sectionHeading)

            switchSection
            accentSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Switches

    /// The three switches and the divider under them.
    ///
    /// **One block, not one section per switch.** The screen already
    /// establishes the pattern: an unheaded block of rows directly under the
    /// page heading, then a headed section for the accent list. All three
    /// switches are the same kind of thing — a label and a track, on or off —
    /// so they belong to that block, and a heading over each would invent a
    /// taxonomy for three rows. It also keeps the column as short as it can
    /// be, which is the constraint that actually bites in landscape.
    ///
    /// The order is by reach. Sound is heard on the countdown *and* the
    /// interval and is the switch a user is most likely to go looking for, so
    /// it leads. Seconds change one page, and swipe-to-dismiss changes one
    /// state on one page, so it trails.
    ///
    /// The divider belongs to this section rather than sitting between the
    /// two, because the export ties it to the rows with the tighter of the two
    /// gaps. It closes the block, so it stays last no matter how many rows sit
    /// above it.
    private var switchSection: some View {
        VStack(spacing: metrics.settingsRowSpacing) {
            SettingsToggleRow(label: LoopStrings.sound, isOn: $sound)
            SettingsToggleRow(label: LoopStrings.secondsInTheClock, isOn: $showSeconds)
            SettingsToggleRow(label: LoopStrings.swipeToDismiss, isOn: $swipeToDismiss)

            Rectangle()
                .fill(ink.hair)
                .frame(height: metrics.hairlineWidth)
        }
    }

    // MARK: - Accent

    private var accentSection: some View {
        VStack(alignment: .leading, spacing: metrics.accentSectionSpacing) {
            Text(LoopStrings.accentColour)
                .loopTextStyle(typography.sectionHeading)

            VStack(spacing: metrics.accentListSpacing) {
                ForEach(LoopAccent.allCases) { candidate in
                    AccentRow(accent: candidate, isActive: candidate == accent) {
                        guard candidate != accent else { return }
                        withAnimation(LoopMotion.resolve(LoopMotion.selection, reduceMotion: reduceMotion)) {
                            accent = candidate
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Footer

/// The line above the navigation dots. The only place Levo Studio is named.
private struct SettingsFooter: View {

    @Environment(\.loopTypography) private var typography
    @Environment(\.loopInk) private var ink

    var body: some View {
        Text(LoopStrings.footer)
            .loopTextStyle(typography.footer)
            .foregroundStyle(ink.base)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Switch row

/// One row of the switch block: a label on the leading edge and a track on the
/// trailing one.
///
/// A type of its own rather than three copies of the same `HStack`. Three rows
/// that look alike by accident drift the moment one of them is touched, and the
/// export draws exactly one row style here — so there is one row, called three
/// times, and no way for the second one to end up 2 pt taller than the first.
private struct SettingsToggleRow: View {

    let label: LocalizedStringResource
    @Binding var isOn: Bool

    @Environment(\.loopTypography) private var typography
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(LoopMotion.resolve(LoopMotion.selection, reduceMotion: reduceMotion)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 0) {
                Text(label)
                    .loopTextStyle(typography.settingsRow)

                Spacer(minLength: 0)

                SettingsToggle(isOn: isOn)
            }
            // The whole row takes the tap, not just the pill. The row is as
            // tall as the track the design draws, so this does not buy the
            // 44 pt a finger wants — it widens the target rather than
            // heightening it, and a settings row that reacts to a tap
            // anywhere along it is what the platform does everywhere else.
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: $isOn) { Text(label) }
        }
    }
}

// MARK: - Toggle

/// The 50 × 29 pt track with its 23 pt knob.
///
/// The knob is drawn in the page background rather than in an ink, so it reads
/// as a hole punched through the accent rather than as a dot laid on top of it.
///
/// - Note: **The off state is not in the export.** Neither file draws this
///   toggle off, in either scheme or on either idiom, so it is an invention and
///   should be read as one. It keeps the drawn geometry and moves the knob to
///   the leading inset; the track takes `hairStrong`, the tone the design gives
///   an inactive *object* — the stepper circles, the secondary button — rather
///   than `hair`, which belongs to 1 pt lines. A 50 × 29 pt capsule at 15 %
///   sits at 1.19 : 1 against the background and all but vanishes.
private struct SettingsToggle: View {

    let isOn: Bool

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopPalette) private var palette
    @Environment(\.loopInk) private var ink

    var body: some View {
        ZStack {
            Capsule()
                .fill(isOn ? palette.marker : ink.hairStrong)

            Circle()
                .fill(palette.background)
                .frame(width: metrics.toggleKnobSize, height: metrics.toggleKnobSize)
                // An offset from the centre rather than a switched `ZStack`
                // alignment: alignment is not animatable, so the knob would
                // jump between the insets while the caller's `withAnimation`
                // wrapped a change with nothing animatable in it.
                .offset(x: isOn ? knobOffset : -knobOffset)
        }
        .frame(width: metrics.toggleSize.width, height: metrics.toggleSize.height)
    }

    /// Half the distance the knob travels: the track's half width, less the
    /// inset and the knob's own half width.
    private var knobOffset: CGFloat {
        (metrics.toggleSize.width - metrics.toggleKnobSize) / 2 - metrics.toggleKnobInset
    }
}

// MARK: - Accent row

/// One row of the accent list: a swatch in that accent's marker colour, its
/// name, and the marker word on whichever row is in use.
///
/// The swatch asks the current palette for a foreign accent's colour rather than
/// building a palette per row — the list shows all four at once, but it shows
/// them in the scheme the app is running in.
private struct AccentRow: View {

    let accent: LoopAccent
    let isActive: Bool
    let action: () -> Void

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopPalette) private var palette
    @Environment(\.loopInk) private var ink

    var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.accentRowSpacing) {
                RoundedRectangle(cornerRadius: metrics.accentSwatchRadius)
                    .fill(palette.swatch(for: accent))
                    .frame(width: metrics.accentSwatchSize, height: metrics.accentSwatchSize)

                Text(LoopStrings.accentName(accent))
                    .loopTextStyle(typography.accentName)

                Spacer(minLength: 0)

                if isActive {
                    Text(LoopStrings.activeAccent)
                        .loopTextStyle(typography.accentActiveMarker)
                }
            }
            .foregroundStyle(ink.base)
            .padding(metrics.accentRowPadding)
            // The border sits *outside* the padding. The export has no
            // `box-sizing` reset, so its rows are content-box: 20 pt of swatch,
            // 22 pt of padding and 3 pt of border make a 45 pt row. A stroke
            // drawn inside the padded frame would eat 1.5 pt off every edge and
            // leave every row 3 pt short.
            .padding(metrics.accentRowBorderWidth)
            .background(background)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    /// The active row is filled and outlined in the accent; the others carry
    /// the inactive hairline and no fill. Both borders are 1.5 pt — the export
    /// draws the inactive ones at the same width, only in a different tone.
    ///
    /// `strokeBorder` on the outer frame is what makes this a CSS border: it
    /// strokes inwards from the edge the radius is measured on, so the 1.5 pt
    /// lands between the frame and the padding, exactly where the export puts
    /// it.
    private var background: some View {
        RoundedRectangle(cornerRadius: metrics.accentRowRadius)
            .fill(isActive ? ink.chip : .clear)
            .overlay {
                RoundedRectangle(cornerRadius: metrics.accentRowRadius)
                    .strokeBorder(
                        isActive ? palette.marker : ink.hair,
                        lineWidth: metrics.accentRowBorderWidth
                    )
            }
    }
}

// MARK: - Preview

#Preview {
    SettingsScreen()
        .environment(LoopSettings(defaults: UserDefaults(suiteName: "preview") ?? .standard))
}
