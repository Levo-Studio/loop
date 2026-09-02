import SwiftUI
import Testing

@testable import Loop

// MARK: - Navigation strip

/// The dots have to follow the swipe while it happens, not settle onto the page
/// once it is over. These tests hold the arithmetic that makes that true: a
/// reading taken halfway through a gesture reports halfway, the row moves by
/// what it has to move to stand still, and the row never changes width.
@Suite("Navigation strip")
struct NavigationStripTests {

    /// A page 400 pt wide, standing `travel` pages away from the window.
    ///
    /// The row sits 166 pt into the page — an arbitrary inset, and the point of
    /// it: the measurement must come out of the two left edges, so where the
    /// row is centred inside its page cannot enter into it.
    private func strip(index: Int, travel: CGFloat, width: CGFloat = 400) -> NavigationStrip {
        let page = CGRect(x: -166, y: -700, width: width, height: 800)
        let visible = CGRect(x: page.minX + travel * width, y: page.minY, width: width, height: 800)
        return NavigationStrip(count: 5, index: index, page: page, visible: visible)
    }

    @Test("A page at rest is the current one and its row has not moved")
    func atRest() {
        let strip = strip(index: 2, travel: 0)

        #expect(strip.shift == 0)
        #expect(strip.position == 2)
        #expect(strip.weight(of: 2) == 1)
        #expect(strip.weight(of: 1) == 0)
        #expect(strip.weight(of: 3) == 0)
    }

    @Test("Halfway through a swipe the strip reads halfway")
    func midSwipe() {
        let strip = strip(index: 2, travel: 0.5)

        // The pages have moved half a width to the left, so the row moves half
        // a width to the right to stay where it was drawn.
        #expect(strip.shift == 200)
        #expect(strip.position == 2.5)
        #expect(strip.weight(of: 2) == 0.5)
        #expect(strip.weight(of: 3) == 0.5)
        #expect(strip.weight(of: 1) == 0)
    }

    @Test("A quarter of a swipe reads a quarter, not the page it started on")
    func earlyInTheSwipe() {
        let strip = strip(index: 0, travel: 0.25)

        #expect(strip.position == 0.25)
        #expect(strip.weight(of: 0) == 0.75)
        #expect(strip.weight(of: 1) == 0.25)
    }

    @Test("Every page reads the same position, so the two rows on screen agree")
    func rowsAgree() {
        // The strip stands between page 2 and page 3. Page 2 sees it a third of
        // a page ahead, page 3 two thirds behind, and both have to draw the
        // same row or the seam at the page boundary would show.
        let left = strip(index: 2, travel: 1.0 / 3)
        let right = strip(index: 3, travel: -2.0 / 3)

        #expect(abs(left.position - right.position) < 1e-9)
        #expect(abs(left.weight(of: 2) - right.weight(of: 2)) < 1e-9)
        #expect(abs(left.weight(of: 3) - right.weight(of: 3)) < 1e-9)
    }

    @Test("The weights add to one at every point of a swipe, so the row keeps its width")
    func widthIsConstant() {
        for step in 0...40 {
            let strip = strip(index: 0, travel: CGFloat(step) / 10)
            let total = (0..<5).reduce(0.0) { $0 + strip.weight(of: $1) }

            #expect(abs(total - 1) < 1e-9, "at \(strip.position)")
        }
    }

    @Test("A bounce past the ends leaves the first and last dot fully active")
    func bounceIsClamped() {
        #expect(strip(index: 0, travel: -0.4).position == 0)
        #expect(strip(index: 0, travel: -0.4).weight(of: 0) == 1)
        #expect(strip(index: 4, travel: 0.4).position == 4)
        #expect(strip(index: 4, travel: 0.4).weight(of: 4) == 1)
    }

    @Test("Without a measurement the row sits still and clips nothing")
    func unmeasured() {
        let strip = NavigationStrip(count: 5, index: 3, page: .null, visible: .null)

        #expect(strip.shift == 0)
        #expect(strip.window.isNull)
        #expect(strip.position == 3)
        #expect(strip.weight(of: 3) == 1)
    }

    @Test("The window is the page, so each row is clipped to the half it owns")
    func window() {
        let strip = strip(index: 1, travel: 0.5)

        #expect(strip.window == CGRect(x: -166, y: -700, width: 400, height: 800))
    }
}
