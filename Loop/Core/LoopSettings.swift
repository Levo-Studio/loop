import Foundation
import Observation

// MARK: - Settings

/// The two things the user can change, and the only state that outlives a run
/// of the app on purpose.
///
/// One type rather than two `@AppStorage` properties scattered over the views:
/// the accent decides every colour on every page, so it has to be readable from
/// one place, and a second copy of it somewhere else would eventually disagree.
@Observable
final class LoopSettings {

    // MARK: - Stored keys

    /// Namespaced, so nothing in the app can collide with a system default.
    private enum Key {
        static let showSeconds = "loop.settings.showSeconds"
        static let accent = "loop.settings.accent"
    }

    private let defaults: UserDefaults

    // MARK: - Values

    /// Whether the clock shows seconds. On by default — the export's clock
    /// screen is drawn with them, and a study timer is a device you glance at
    /// to see something moving.
    var showSeconds: Bool {
        didSet { defaults.set(showSeconds, forKey: Key.showSeconds) }
    }

    /// The chosen accent.
    var accent: LoopAccent {
        didSet { defaults.set(accent.rawValue, forKey: Key.accent) }
    }

    // MARK: - Life cycle

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // `object(forKey:)` rather than `bool(forKey:)`, because the latter
        // cannot tell a stored `false` from nothing stored at all, and the
        // default here is `true`.
        self.showSeconds = defaults.object(forKey: Key.showSeconds) as? Bool ?? true

        let storedAccent = defaults.string(forKey: Key.accent)
        self.accent = storedAccent.flatMap(LoopAccent.init(rawValue:)) ?? .default
    }
}
