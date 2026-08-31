import SwiftUI

// MARK: - Count-up

/// A stopwatch. No rising area either: without a total there is no fraction to
/// fill, and the export leaves the page flat on purpose.
///
/// - Note: The idle, running and paused states and their controls belong to
///   this feature and are filled in here.
struct CountUpScreen: View {

    var body: some View {
        PageScaffold {
            StatusPill(label: LoopStrings.countUp)
        } content: {
            TimeDisplay(time: Self.placeholderTime, secondary: LoopStrings.ready)
        } controls: {
            ControlRow(
                primary: .init(LoopStrings.start) {},
                secondary: .init(LoopStrings.reset, isEnabled: false) {}
            )
        }
    }

    private static let placeholderTime = "00:00"
}

#Preview {
    CountUpScreen()
}
