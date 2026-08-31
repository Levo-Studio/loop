import SwiftUI

// MARK: - Page

/// The five pages, in the order they are swiped through. There is no sixth and
/// no wrap-around: the order is the navigation, and a list that closes into a
/// ring would take away the only sense of where you are.
nonisolated enum LoopPage: Int, CaseIterable, Identifiable, Sendable {
    case clock
    case countUp
    case countdown
    case interval
    case settings

    var id: Int { rawValue }
}

// MARK: - Environment

extension EnvironmentValues {

    /// The page a view is being drawn inside. Only the navigation dots need it,
    /// and they need it from far enough down that passing it by hand through
    /// every screen would be noise.
    @Entry var loopPage = LoopPage.clock
}
