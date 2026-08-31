import SwiftUI

// MARK: - Settings

/// The seconds toggle and the accent list, over a footer. No status pill and no
/// rising area — this page is the only one that is not a timer.
///
/// - Note: The toggle, the accent rows and the footer belong to this feature and
///   are filled in here.
struct SettingsScreen: View {

    @Environment(\.loopTypography) private var typography
    @Environment(\.loopInk) private var ink

    var body: some View {
        PageScaffold {
            EmptyView()
        } content: {
            VStack(alignment: .leading) {
                Text(LoopStrings.settings)
                    .loopTextStyle(typography.sectionHeading)
                    .foregroundStyle(ink.base)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } controls: {
            Text(LoopStrings.footer)
                .loopTextStyle(typography.footer)
                .foregroundStyle(ink.base)
        }
    }
}

#Preview {
    SettingsScreen()
}
