import Testing
import Foundation

@testable import Loop

// MARK: - Settings

@Suite("Settings")
struct LoopSettingsTests {

    /// A throwaway suite name per test, so one test cannot read what another
    /// wrote and no run touches the app's real defaults.
    private func makeDefaults() -> UserDefaults {
        let suiteName = "loop.tests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName) ?? .standard
    }

    @Test("A fresh install starts on petrol with seconds, sound and swipe on")
    func defaults() {
        let settings = LoopSettings(defaults: makeDefaults())
        #expect(settings.accent == .petrol)
        #expect(settings.showSeconds)

        // Both of these are on by default because a timer nobody hears and a
        // finished alarm that clears itself are the versions of the feature
        // that do nothing.
        #expect(settings.sound)
        #expect(settings.swipeToDismiss)
    }

    @Test("Every value survives a restart")
    func persistence() {
        let defaults = makeDefaults()

        let first = LoopSettings(defaults: defaults)
        first.accent = .lilac
        first.showSeconds = false
        first.sound = false
        first.swipeToDismiss = false

        let second = LoopSettings(defaults: defaults)
        #expect(second.accent == .lilac)

        // `false` has to come back as `false`, not as the default `true` —
        // which is why the initialiser asks whether anything is stored rather
        // than asking `UserDefaults` for a bool. All three defaulting to `true`
        // means all three would fail the same way.
        #expect(!second.showSeconds)
        #expect(!second.sound)
        #expect(!second.swipeToDismiss)
    }

    @Test("Turning a switch back on survives too")
    func reEnabling() {
        // The counter-check to the test above: reading `false` correctly is
        // only half of it, and a getter hard-wired to `false` would pass there.
        let defaults = makeDefaults()

        let first = LoopSettings(defaults: defaults)
        first.sound = false
        first.swipeToDismiss = false
        first.sound = true
        first.swipeToDismiss = true

        let second = LoopSettings(defaults: defaults)
        #expect(second.sound)
        #expect(second.swipeToDismiss)
    }

    @Test("The two new switches are stored under their own keys")
    func separateKeys() {
        // They default alike and are written alike, so a copied `didSet`
        // pointing both at one key would look correct in every test above.
        let defaults = makeDefaults()

        let settings = LoopSettings(defaults: defaults)
        settings.sound = false

        #expect(defaults.object(forKey: "loop.settings.sound") as? Bool == false)
        #expect(defaults.object(forKey: "loop.settings.swipeToDismiss") == nil)
        #expect(settings.swipeToDismiss)
    }

    @Test("An accent that no longer exists falls back instead of crashing")
    func unknownStoredAccent() {
        let defaults = makeDefaults()
        defaults.set("teal", forKey: "loop.settings.accent")

        #expect(LoopSettings(defaults: defaults).accent == .petrol)
    }
}
