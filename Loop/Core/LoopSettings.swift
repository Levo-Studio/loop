import Foundation
import Observation

// MARK: - Settings

/// The things the user can change, and the only state that outlives a run of
/// the app on purpose.
///
/// One type rather than a handful of `@AppStorage` properties scattered over
/// the views: the accent decides every colour on every page, so it has to be
/// readable from one place, and a second copy of it somewhere else would
/// eventually disagree.
@Observable
final class LoopSettings {

    // MARK: - Stored keys

    /// Namespaced, so nothing in the app can collide with a system default.
    private enum Key {
        static let showSeconds = "loop.settings.showSeconds"
        static let accent = "loop.settings.accent"
        static let sound = "loop.settings.sound"
        static let swipeToDismiss = "loop.settings.swipeToDismiss"
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

    /// Whether the app plays a tone at a block boundary and at a finish. On by
    /// default — a timer you have to watch is not a timer.
    ///
    /// **One switch for all three tones, not one per tone.** The three cues are
    /// one behaviour: the app makes a noise when something changes. Nobody
    /// wants the tone for a block ending but not the one for the next
    /// beginning — that is precisely the pair whose whole value is being told
    /// apart, and half of it is worse than neither. Three rows would also
    /// double a settings page that has two, to sell a combination nobody asks
    /// for.
    var sound: Bool {
        didSet { defaults.set(sound, forKey: Key.sound) }
    }

    /// Whether the countdown's finished state has to be swiped away, like an
    /// alarm. On by default, as the owner decided.
    ///
    /// Read through `LoopDismissal.requiresSwipe(_:swipeToDismissEnabled:)`
    /// rather than directly: the interval ignores this setting, and that
    /// asymmetry belongs in one function instead of in each of the two screens
    /// that draw a finished state.
    var swipeToDismiss: Bool {
        didSet { defaults.set(swipeToDismiss, forKey: Key.swipeToDismiss) }
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

        // Same reason as `showSeconds`: both default to `true`, and
        // `bool(forKey:)` would read a deliberately stored `false` as nothing
        // stored and hand the default back.
        self.sound = defaults.object(forKey: Key.sound) as? Bool ?? true
        self.swipeToDismiss = defaults.object(forKey: Key.swipeToDismiss) as? Bool ?? true
    }
}
