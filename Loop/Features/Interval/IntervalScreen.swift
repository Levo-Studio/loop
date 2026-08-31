import SwiftUI

// MARK: - Interval

/// Focus and break blocks over a number of rounds, sharing the one rising area.
/// Only the status pill and the round counter say which block is running.
///
/// - Note: The setup scales, the round stepper, the block sequence and the
///   finished state belong to this feature and are filled in here.
struct IntervalScreen: View {

    var body: some View {
        PageScaffold {
            StatusPill(label: LoopStrings.interval)
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
    IntervalScreen()
}
