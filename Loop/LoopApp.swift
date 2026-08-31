import SwiftUI

// MARK: - App

@main
struct LoopApp: App {

    /// The settings outlive every view, so they are created once here and read
    /// from the environment everywhere else. Nothing in the app writes them
    /// except the settings page.
    @State private var settings = LoopSettings()

    /// The three timers, read back from disk here and nowhere else.
    ///
    /// They are created next to the settings because they outlive every view
    /// for the same reason: a run belongs to the app, not to the page that
    /// happens to be on screen when it is started. Reading the record at this
    /// point means the first frame is already drawn for the run the clock says
    /// is in progress, rather than showing a fresh timer and correcting itself.
    @State private var timers = LoopTimers()

    var body: some Scene {
        WindowGroup {
            RootShell()
                .environment(settings)
                .environment(timers)
        }
    }
}
