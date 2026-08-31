import Testing

@testable import Loop

/// The test bundle exists so the design layer and, later, the engine can be
/// checked without a simulator run. This suite only proves the target links
/// against the app module and that Swift Testing is wired up; the real tests
/// live next to the thing they cover.
@Suite("Test bundle")
struct LoopTestBundleTests {

    @Test("Swift Testing runs against the app module")
    func swiftTestingRuns() {
        #expect(Bool(true))
    }
}
