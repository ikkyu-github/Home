import XCTest
@testable import BrowserCore

final class RenderBudgetPolicyTests: XCTestCase {
    func testOverviewKeepsZeroRendered() {
        let a = UUID()
        let b = UUID()

        let decision = RenderBudgetPolicy.decide(
            input: .init(
                isSplitEnabled: true,
                isTabOverviewVisible: true,
                activePane: .left,
                activeTabID: a,
                leftTabID: a,
                rightTabID: b,
                bindingTabID: nil
            ),
            candidates: [a, b]
        )

        XCTAssertEqual(decision.keepRendered, [])
        XCTAssertEqual(decision.freeze, Set([a, b]))
    }

    func testSplitPrefersBindingThenActivePaneAndCapsAtTwo() {
        let binding = UUID()
        let left = UUID()
        let right = UUID()

        let decision = RenderBudgetPolicy.decide(
            input: .init(
                isSplitEnabled: true,
                isTabOverviewVisible: false,
                activePane: .left,
                activeTabID: left,
                leftTabID: left,
                rightTabID: right,
                bindingTabID: binding
            ),
            candidates: [binding, left, right]
        )

        XCTAssertEqual(decision.keepRendered.count, 2)
        XCTAssertEqual(decision.keepRendered[0], binding)
        XCTAssertEqual(decision.keepRendered[1], left)
        XCTAssertTrue(decision.freeze.contains(right))
    }

    func testSinglePaneKeepsOneRendered() {
        let active = UUID()
        let other = UUID()

        let decision = RenderBudgetPolicy.decide(
            input: .init(
                isSplitEnabled: false,
                isTabOverviewVisible: false,
                activePane: .left,
                activeTabID: active,
                leftTabID: active,
                rightTabID: other,
                bindingTabID: nil
            ),
            candidates: [active, other]
        )

        XCTAssertEqual(decision.keepRendered, [active])
        XCTAssertEqual(decision.freeze, Set([other]))
    }
}
