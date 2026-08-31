import SwiftUI

// MARK: - Settings

/// The seconds toggle and the accent list, over a footer. No status pill and no
/// rising area — this page is the only one that is not a timer, so there is no
/// duration to measure and nothing to show progress against.
///
/// Both settings are written straight into `LoopSettings`, which the shell reads
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
            SettingsColumn(showSeconds: $settings.showSeconds, accent: $settings.accent)
        } controls: {
            SettingsFooter()
        }
    }
}

// MARK: - Column

/// The heading, the seconds row and the accent list.
///
/// A view of its own rather than a `@ViewBuilder` on the screen, because the ink
/// has to be read from inside `PageScaffold`. `FillSurface` puts the tone for
/// the layer it is drawing into the environment, so a screen reading `loopInk`
/// above the scaffold gets the default rather than the running palette — the
/// text would keep the light scheme's ink in dark mode. Every component in the
/// design layer reads it at the leaf for the same reason.
private struct SettingsColumn: View {

    @Binding var showSeconds: Bool
    @Binding var accent: LoopAccent

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopInk) private var ink
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.settingsSectionSpacing) {
            Text(LoopStrings.settings)
                .loopTextStyle(typography.sectionHeading)

            secondsSection
            accentSection
        }
        .foregroundStyle(ink.base)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Seconds

    /// The seconds row and the divider under it. The divider belongs to this
    /// section rather than sitting between the two, because the export ties it
    /// to the row with the tighter of the two gaps.
    private var secondsSection: some View {
        VStack(spacing: metrics.settingsRowSpacing) {
            Button {
                withAnimation(LoopMotion.resolve(LoopMotion.selection, reduceMotion: reduceMotion)) {
                    showSeconds.toggle()
                }
            } label: {
                HStack(spacing: 0) {
                    Text(LoopStrings.secondsInTheClock)
                        .loopTextStyle(typography.settingsRow)

                    Spacer(minLength: 0)

                    SecondsToggle(isOn: showSeconds)
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
                Toggle(isOn: $showSeconds) { Text(LoopStrings.secondsInTheClock) }
            }

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

// MARK: - Seconds toggle

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
private struct SecondsToggle: View {

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
