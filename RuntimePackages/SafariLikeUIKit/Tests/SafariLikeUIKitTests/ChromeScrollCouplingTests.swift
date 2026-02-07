import XCTest
import SafariLikeUXKit

final class ChromeScrollCouplingTests: XCTestCase {

    func testScrollDownCollapses() {
        var m = ChromeStateMachine(initialState: .expanded, initialScrollY: 0)
        _ = m.transition(.scroll(y: 0, velocityY: 0))
        _ = m.transition(.scroll(y: 30, velocityY: 1200))
        XCTAssertEqual(m.snapshot.state, .collapsed)
    }

    func testScrollUpExpands() {
        var m = ChromeStateMachine(initialState: .collapsed, initialScrollY: 100)
        _ = m.transition(.scroll(y: 100, velocityY: 0))
        _ = m.transition(.scroll(y: 80, velocityY: -200))
        XCTAssertEqual(m.snapshot.state, .expanded)
    }
}
