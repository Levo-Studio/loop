import SwiftUI

// MARK: - Surface

/// Puts Loop's design layer into the environment of a Live Activity view.
///
/// The extension is a separate process with an empty environment: none of the
/// defaults the app installs at its root are there, so a `StatusPill` dropped
/// into a widget would resolve the *default* palette and draw petrol under an
/// amber accent. This is the one place that fills it in, and every presentation
/// — lock screen, compact, minimal, expanded — goes through it.
///
/// The scheme comes from the environment rather than from the payload. The lock
/// screen and the Dynamic Island follow the system appearance, and the accent's
/// light and dark values are two lightnesses of one hue, so reading it here is
/// what keeps the widget matching the phone rather than the app's last frame.
struct LoopActivitySurface<Content: View>: View {

    let accentID: String

    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var scheme

    /// An accent written by a build that knows a fifth one falls back to the
    /// default rather than failing the whole state.
    private var accent: LoopAccent {
        LoopAccent(rawValue: accentID) ?? .default
    }

    var body: some View {
        let palette = LoopPalette(accent: accent, scheme: scheme)

        content
            .environment(\.loopPalette, palette)
            .environment(\.loopInk, palette.inkOnBackground)
            // A Live Activity is drawn at one size on every device, so the
            // idiom scale that the app takes from the size class has nothing to
            // read here. iPhone portrait is the reference the export is drawn
            // at, and it is what the lock screen gets.
            .environment(\.loopMetrics, LoopMetrics(isPad: false, isLandscape: false))
            .environment(\.loopTypography, LoopTypography(scale: 1, isLandscape: false))
            .foregroundStyle(palette.inkOnBackground.base)
    }
}
