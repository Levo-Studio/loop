import SwiftUI

// MARK: - Root shell

/// The whole app: five pages side by side, swiped horizontally, and nothing
/// else. No tab bar, no title, no button that changes mode. The dots at the
/// bottom of each page are the only thing that says where you are.
///
/// The shell owns three things the screens must not decide for themselves: which
/// palette is in force, what the idiom and orientation make of the metrics, and
/// where the safe area is. All three go into the environment here, once.
struct RootShell: View {

    @Environment(LoopSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    /// The page the user chose, and the only thing that decides where the strip
    /// stands after the geometry moves.
    ///
    /// Deliberately not the scroll view's own position. A rotation resizes every
    /// page, and the scroll view settles the offset inside whatever content it
    /// has at that moment — which is not a scroll, so nothing puts the strip
    /// back afterwards and the user rotates the phone onto a screen they never
    /// asked for. Measured on an iPhone 17 Pro from the interval page: portrait
    /// offset 1206 of 2010, and after a turn to landscape and back, 804 — the
    /// countdown page.
    ///
    /// Keeping the intent separate is what makes it recoverable: only a settled
    /// gesture writes this, and a change of size re-asserts it.
    @State private var page: LoopPage = .clock

    /// The scroll view's position. Imperative on purpose — re-asserting the
    /// page after a resize means scrolling to an id the binding already holds,
    /// which a plain `scrollPosition(id:)` binding cannot express because
    /// writing the same value to it is not a change.
    @State private var position = ScrollPosition(id: LoopPage.clock)

    var body: some View {
        GeometryReader { proxy in
            // The reader sits inside the safe area on purpose: it is the only
            // place the insets can still be read, and the pages below it go
            // edge to edge. The page size has to be the whole screen, so the
            // insets are added back to the size the reader reports.
            let insets = proxy.safeAreaInsets
            let size = CGSize(
                width: proxy.size.width + insets.leading + insets.trailing,
                height: proxy.size.height + insets.top + insets.bottom
            )
            let metrics = LoopMetrics(isPad: isPad, isLandscape: size.width > size.height)

            pages(size: size)
                // A resize is the one moment the strip can end up somewhere
                // nobody asked for, so it is also the moment the chosen page is
                // put back. Same page, new geometry: the scroll is a jump and
                // there is nothing to animate.
                .onChange(of: size) { position.scrollTo(id: page) }
                .environment(\.loopMetrics, metrics)
                .environment(\.loopSafeAreaInsets, insets)
                .environment(\.loopTypography, LoopTypography(scale: metrics.scale, isLandscape: metrics.isLandscape))
                .environment(\.loopPalette, LoopPalette(accent: settings.accent, scheme: colorScheme))
        }
        .background(settings.accent.background(colorScheme).ignoresSafeArea())
    }

    // MARK: - Paging

    /// A horizontal scroll view with paging behaviour rather than a `TabView`:
    /// it pages without an index overlay to switch off, and its content keeps
    /// the size it is given instead of being inset by a style.
    ///
    /// **`HStack`, not `LazyHStack`, and the reason is the rotation above.** A
    /// lazy stack re-measures its children one at a time after a resize and
    /// reports an estimate until it is done; measured on an iPhone 17 Pro the
    /// landscape strip stood at 2884 pt where five pages are 4370, and it stayed
    /// there — long enough for the paging offset to settle between two pages,
    /// with one screen's controls in view beside another's. Building all five
    /// costs nothing that was being saved: lazy only ever governed the first
    /// build, and one pass through the strip realises every page for the rest of
    /// the run.
    private func pages(size: CGSize) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(LoopPage.allCases) { page in
                    screen(for: page)
                        .environment(\.loopPage, page)
                        .frame(width: size.width, height: size.height)
                        .id(page)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        // Only a gesture that has come to rest counts as a choice. A clamp
        // during a resize moves the strip without ever going through a scroll
        // phase, which is exactly the difference this is here to keep.
        .onScrollPhaseChange { _, phase in
            guard phase == .idle, let landed = position.viewID(type: LoopPage.self) else { return }
            page = landed
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        // Only the scroll view goes edge to edge. The reader above it stays
        // inside the safe area, which is the one place the insets can still be
        // read before they are given up.
        .ignoresSafeArea()
    }

    @ViewBuilder private func screen(for page: LoopPage) -> some View {
        switch page {
        case .clock: ClockScreen()
        case .countUp: CountUpScreen()
        case .countdown: CountdownScreen()
        case .interval: IntervalScreen()
        case .settings: SettingsScreen()
        }
    }

    // MARK: - Idiom

    /// The idiom decides the type and layout scale, and it cannot change while
    /// the app runs — unlike the size class, which changes with every split
    /// view and would rescale the whole design mid-gesture.
    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

// MARK: - Preview

#Preview {
    RootShell()
        .environment(LoopSettings(defaults: UserDefaults(suiteName: "preview") ?? .standard))
        .environment(LoopTimers(store: TimerStateStore(defaults: UserDefaults(suiteName: "preview") ?? .standard)))
}
