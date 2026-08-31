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
    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopTypography) private var typography
    @Environment(\.loopInk) private var ink
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // `@Bindable` here rather than inside a slot: the slots are built twice
        // by `FillSurface`, and anything declared in them exists twice. This is
        // a projection of shared state, not storage, but it belongs outside for
        // the same reason the rest of the state does.
        @Bindable var settings = settings

        return PageScaffold {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: metrics.settingsSectionSpacing) {
                Text(LoopStrings.settings)
                    .loopTextStyle(typography.sectionHeading)

                secondsSection(isOn: $settings.showSeconds)
                accentSection
            }
            .foregroundStyle(ink.base)
            .frame(maxWidth: .infinity, alignment: .leading)
        } controls: {
            Text(LoopStrings.footer)
                .loopTextStyle(typography.footer)
                .foregroundStyle(ink.base)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Seconds

    /// The seconds row and the divider under it. The divider belongs to this
    /// section rather than sitting between the two, because the export ties it
    /// to the row with the tighter of the two gaps.
    private func secondsSection(isOn: Binding<Bool>) -> some View {
        VStack(spacing: metrics.settingsRowSpacing) {
            Button {
                withAnimation(LoopMotion.resolve(LoopMotion.selection, reduceMotion: reduceMotion)) {
                    isOn.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 0) {
                    Text(LoopStrings.secondsInTheClock)
                        .loopTextStyle(typography.settingsRow)

                    Spacer(minLength: 0)

                    SecondsToggle(isOn: isOn.wrappedValue)
                }
                // The whole row takes the tap, not just the pill: 29 pt of
                // track is under the 44 pt a finger needs, and a settings row
                // that reacts to being tapped anywhere is what the platform
                // does everywhere else.
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityRepresentation {
                Toggle(isOn: isOn) { Text(LoopStrings.secondsInTheClock) }
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
                ForEach(LoopAccent.allCases) { accent in
                    AccentRow(accent: accent, isActive: accent == settings.accent) {
                        guard accent != settings.accent else { return }
                        withAnimation(LoopMotion.resolve(LoopMotion.selection, reduceMotion: reduceMotion)) {
                            settings.accent = accent
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Seconds toggle

/// The 50 × 29 pt track with its 23 pt knob.
///
/// The knob is drawn in the page background rather than in an ink, so it reads
/// as a hole punched through the accent rather than as a dot laid on top of it.
///
/// - Note: The export draws the toggle in its on state only, in both schemes.
///   The off state moves the knob to the leading inset and drops the track to
///   `hair`, the tone the design gives every inactive surface.
private struct SecondsToggle: View {

    let isOn: Bool

    @Environment(\.loopMetrics) private var metrics
    @Environment(\.loopPalette) private var palette
    @Environment(\.loopInk) private var ink

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? palette.marker : ink.hair)

            Circle()
                .fill(palette.background)
                .frame(width: metrics.toggleKnobSize, height: metrics.toggleKnobSize)
                .padding(metrics.toggleKnobInset)
        }
        .frame(width: metrics.toggleSize.width, height: metrics.toggleSize.height)
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
            .background(background)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    /// The active row is filled and outlined in the accent; the others carry
    /// the inactive hairline and no fill. Both borders are 1.5 pt — the export
    /// draws the inactive ones at the same width, only in a different tone.
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
