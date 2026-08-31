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

    @Test("A fresh install starts on petrol with seconds showing")
    func defaults() {
        let settings = LoopSettings(defaults: makeDefaults())
        #expect(settings.accent == .petrol)
        #expect(settings.showSeconds)
    }

    @Test("Both values survive a restart")
    func persistence() {
        let defaults = makeDefaults()

        let first = LoopSettings(defaults: defaults)
        first.accent = .lilac
        first.showSeconds = false

        let second = LoopSettings(defaults: defaults)
        #expect(second.accent == .lilac)

        // `false` has to come back as `false`, not as the default `true` —
        // which is why the initialiser asks whether anything is stored rather
        // than asking `UserDefaults` for a bool.
        #expect(!second.showSeconds)
    }

    @Test("An accent that no longer exists falls back instead of crashing")
    func unknownStoredAccent() {
        let defaults = makeDefaults()
        defaults.set("teal", forKey: "loop.settings.accent")

        #expect(LoopSettings(defaults: defaults).accent == .petrol)
    }
}
