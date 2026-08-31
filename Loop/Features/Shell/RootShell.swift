import SwiftUI

// MARK: - Root shell

/// The whole app: five pages side by side, swiped horizontally, and nothing
/// else. No tab bar, no title, no button that changes mode. The dots at the
/// bottom of each page are the only thing that says where you are.
///
/// The shell owns three things the screens must not decide for themselves: which
/// palette is in force, what the idiom and orientation make of the metrics, and
/// where the safe area is. All three go into the environment here, once.
///
/// It also owns whether the display may go to sleep. That question is about
/// every page at once — a countdown does not stop running because the user
/// swiped to the clock — so it cannot be answered from inside a screen, and
/// five screens each holding an opinion is five chances to leave it switched
/// on.
struct RootShell: View {

    @Environment(LoopSettings.self) private var settings
    @Environment(LoopTimers.self) private var timers
    @Environment(\.colorScheme) private var colorScheme

    /// Read so the answer below is re-taken on the way back to the foreground.
    /// A run that ended while the app was away left the flag standing, and iOS
    /// applies it again the moment Loop is frontmost.
    @Environment(\.scenePhase) private var scenePhase

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
        .task(id: DisplayWake(state: timers.state, scenePhase: scenePhase)) { await holdDisplayAwake() }
    }

    // MARK: - Keeping the display awake

    /// What the answer depends on besides the clock: the timers themselves, and
    /// whether the app is in front. Any change of either restarts the loop
    /// below, which re-takes the decision immediately.
    private struct DisplayWake: Equatable {
        let state: LoopTimerState
        let scenePhase: ScenePhase
    }

    /// Holds the display awake for exactly as long as a run justifies it.
    ///
    /// The loop is what keeps the flag honest. `LoopIdleTimer` says how long
    /// its answer holds — the remaining time of whichever block ends first — so
    /// the task sleeps until then and asks again, and a countdown reaching zero
    /// switches the screen back to its normal timeout whether or not anybody is
    /// on that page. Without it the flag would only ever be cleared by a tap,
    /// which is the one thing that does not happen when a timer is left to run
    /// out.
    ///
    /// Nothing is done on the way to the background: `isIdleTimerDisabled`
    /// applies to the frontmost app only, so a stale `true` keeps nobody's
    /// screen alive, and coming back re-takes the answer through the id above.
    private func holdDisplayAwake() async {
        while !Task.isCancelled {
            let decision = LoopIdleTimer.decision(for: timers.state, at: .now)
            UIApplication.shared.isIdleTimerDisabled = decision.keepsDisplayAwake

            guard let holdsFor = decision.holdsFor else { return }
            try? await Task.sleep(for: .seconds(holdsFor))
        }
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
