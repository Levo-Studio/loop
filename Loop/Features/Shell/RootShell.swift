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

    @State private var page: LoopPage? = .clock

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
    private func pages(size: CGSize) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
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
        .scrollPosition(id: $page)
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
}
