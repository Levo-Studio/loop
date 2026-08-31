import SwiftUI
import WidgetKit

// MARK: - Widget bundle

/// The extension's entry point.
///
/// Loop ships no home-screen widget, so the bundle holds exactly one member:
/// the Live Activity for the countdown and the interval. The clock and the
/// count-up are absent on purpose — neither has a duration, so neither has a
/// remaining time to count or a progress to raise, and a Live Activity that
/// only mirrors a running number is a notification that never goes away.
@main
struct LoopWidgetBundle: WidgetBundle {

    var body: some Widget {
        LoopActivityWidget()
    }
}
