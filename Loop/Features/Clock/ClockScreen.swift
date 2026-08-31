import SwiftUI

// MARK: - Clock

/// The current time, with seconds when the setting asks for them. No controls
/// and no rising area — there is no duration here, so there is no progress.
///
/// - Note: The clock's own behaviour — the ticking, the formatting, the weekday
///   line — belongs to this feature and is filled in here.
struct ClockScreen: View {

    var body: some View {
        PageScaffold {
            StatusPill(label: LoopStrings.clock)
        } content: {
            TimeDisplay(time: Self.placeholderTime)
        } controls: {
            EmptyView()
        }
    }

    /// Stands in until the clock reads the real time. The five characters are
    /// the reference length the type scale is built around.
    private static let placeholderTime = "00:00"
}

#Preview {
    ClockScreen()
}
