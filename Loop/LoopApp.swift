import SwiftUI

// MARK: - App

@main
struct LoopApp: App {

    /// The settings outlive every view, so they are created once here and read
    /// from the environment everywhere else. Nothing in the app writes them
    /// except the settings page.
    @State private var settings = LoopSettings()

    var body: some Scene {
        WindowGroup {
            RootShell()
                .environment(settings)
        }
    }
}
