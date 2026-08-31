import SwiftUI

// MARK: - Fill surface

/// The app's only progress indicator: a solid area flush to the bottom edge,
/// its height a fraction of the page, and every piece of content that crosses
/// its edge drawn in two tones.
///
/// The content closure is written **once** by the screen and evaluated twice
/// here — once in ink on the background, once in the on-fill tone clipped to the
/// area. That is the prototype's `clip-path` trick, and it is the reason the
/// edge cuts cleanly through a glyph instead of tinting it: both layers are the
/// same drawing at the same position, so the seam is a mask boundary and not a
/// blend. A blend mode would shift the hue of everything underneath and would
/// have to be undone for the accent dot, which is not two-toned.
///
/// The area is a full-size rectangle scaled from its bottom anchor rather than
/// a rectangle of a measured height. Both read the same on screen, but the
/// scaled version needs no geometry reader, so the mask and the fill are
/// guaranteed to be the same shape rather than two computations that agree
/// until a layout pass disagrees.
struct FillSurface<Content: View>: View {

    /// How full the area is, 0…1, over the duration of the **current** block.
    /// Values outside the range are clamped; a caller mid-transition should not
    /// be able to draw an area taller than the page.
    let fraction: Double

    @ViewBuilder let content: () -> Content

    @Environment(\.loopPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(fraction: Double = 0, @ViewBuilder content: @escaping () -> Content) {
        self.fraction = fraction
        self.content = content
    }

    private var clampedFraction: Double { min(1, max(0, fraction)) }

    var body: some View {
        ZStack(alignment: .bottom) {
            palette.background

            area
                .fill(palette.fill)

            content()
                .environment(\.loopInk, palette.inkOnBackground)

            content()
                .environment(\.loopInk, palette.inkOnFill)
                .mask(alignment: .bottom) { area }
        }
        .animation(LoopMotion.resolve(LoopMotion.fill, reduceMotion: reduceMotion), value: clampedFraction)
        .ignoresSafeArea()
    }

    /// The area itself. `scaleEffect` on the y axis from the bottom anchor is
    /// what makes an empty fill a zero-height rectangle rather than a hairline.
    private var area: some Shape {
        Rectangle().scale(x: 1, y: clampedFraction, anchor: .bottom)
    }
}

// MARK: - Preview

#Preview {
    FillSurface(fraction: 0.4) {
        InkText()
    }
}

/// A scrap of content for the preview above, written once and drawn twice by
/// `FillSurface` — which is the whole point being previewed.
private struct InkText: View {

    @Environment(\.loopInk) private var ink

    var body: some View {
        Text(verbatim: "18:42")
            .font(.system(size: 104, weight: .light))
            .foregroundStyle(ink.base)
    }
}
