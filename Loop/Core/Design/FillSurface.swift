import SwiftUI

// MARK: - Fill surface

/// The app's only progress indicator: a solid area flush to the bottom edge,
/// its height a fraction of the page, and every piece of content that crosses
/// its edge drawn in two tones.
///
/// It takes a `FillProgress` rather than a bare fraction, because the area
/// moves in two different ways and only the caller knows which is happening:
/// it slides while a block runs, and jumps when the block changes.
///
/// The content closure is written **once** by the screen and evaluated twice
/// here — once in ink on the background, once in the on-fill tone clipped to the
/// area. That is the prototype's `clip-path` trick, and it is the reason the
/// edge cuts cleanly through a glyph instead of tinting it: both layers are the
/// same drawing at the same position, so the seam is a mask boundary and not a
/// blend. A blend mode would shift the hue of everything underneath and would
/// have to be undone for the accent dot, which is not two-toned.
///
/// ## What the content closure may contain
///
/// Screens meet these rules through `PageScaffold`, where they are repeated on
/// the slots themselves. They are restated here because this is the type that
/// causes them.
///
/// Twice-built content is the price of the edge, and it comes with two rules
/// that are not obvious from a call site:
///
/// - **The content must be a pure drawing of state owned above the surface.**
///   The two layers are separate positions in the view tree, so they get
///   separate identities and separate storage. A `@State` declared inside the
///   closure exists twice and the copies drift apart the moment one is
///   touched — the visible half would move and the clipped half would not.
///   Bindings passed in from the screen are fine; they are one value read
///   twice, which is the whole idea.
/// - **Nothing inside may react to a value changing.** `.onChange`, `.task`
///   and `.sensoryFeedback` are installed on both layers and fire on both.
///   That is why the slider and the stepper fire `LoopHaptics` from their
///   gesture handlers rather than watching their own binding.
///
/// Only one layer takes interactions, so a button or a drag is handled once.
///
/// The area is a full-size rectangle scaled from its bottom anchor rather than
/// a rectangle of a measured height. Both read the same on screen, but the
/// scaled version needs no geometry reader, so the mask and the fill are
/// guaranteed to be the same shape rather than two computations that agree
/// until a layout pass disagrees.
struct FillSurface<Content: View>: View {

    /// How full the area is and which block it measures.
    let progress: FillProgress

    @ViewBuilder let content: () -> Content

    @Environment(\.loopPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The fraction actually drawn.
    ///
    /// Held separately from `progress.fraction` so that moving to a new value
    /// can be animated or not, decided per change. `.animation(_:value:)`
    /// cannot express that: it applies one animation to every change of the
    /// value it watches, which is exactly the bug — it slid the area down over
    /// a second at a block boundary that the design says should jump.
    @State private var drawnFraction: Double = 0

    init(progress: FillProgress = .none, @ViewBuilder content: @escaping () -> Content) {
        self.progress = progress
        self.content = content
    }

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
                // The on-fill layer is a drawing of the layer beneath it and
                // nothing more. Without this both copies are live and a tap
                // near the fill edge could land on either, which is a coin
                // toss over which one owns the gesture.
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onChange(of: progress, initial: true) { previous, current in
            // A new block starts at whatever it starts at, with no travel from
            // the last one. Within a block the area interpolates towards the
            // timer.
            let blockChanged = previous.block != current.block
            withAnimation(LoopMotion.fill(blockChanged: blockChanged, reduceMotion: reduceMotion)) {
                drawnFraction = current.fraction
            }
        }
    }

    /// The area itself. `scaleEffect` on the y axis from the bottom anchor is
    /// what makes an empty fill a zero-height rectangle rather than a hairline.
    private var area: some Shape {
        Rectangle().scale(x: 1, y: drawnFraction, anchor: .bottom)
    }
}

// MARK: - Preview

#Preview {
    FillSurface(progress: FillProgress(fraction: 0.4, block: 0)) {
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
