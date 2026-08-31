import SwiftUI

// MARK: - Countdown

/// One duration, counted down, with the rising area showing how much of it has
/// gone.
///
/// - Note: The idle scale, the running, paused and finished states, and the
///   fraction handed to the scaffold belong to this feature and are filled in
///   here.
struct CountdownScreen: View {

    var body: some View {
        PageScaffold {
            StatusPill(label: LoopStrings.countdown)
        } content: {
            TimeDisplay(time: Self.placeholderTime, secondary: LoopStrings.ready)
        } controls: {
            ControlRow(
                primary: .init(LoopStrings.start) {},
                secondary: .init(LoopStrings.reset, isEnabled: false) {}
            )
        }
    }

    private static let placeholderTime = "25:00"
}

#Preview {
    CountdownScreen()
}
