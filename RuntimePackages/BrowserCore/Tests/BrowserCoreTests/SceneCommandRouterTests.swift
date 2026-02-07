import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class SceneCommandRouterTests: XCTestCase {

    func testCmdLFocusesAddressBarAndDismissesOverview() {
        let router = SceneCommandRouter()
        let tabID = UUID()
        let context = CommandContextSnapshot(
            tabCount: 3,
            activeTabID: tabID,
            tabOverviewSelectedTabID: tabID,
            isTabOverviewVisible: true,
            isAddressBarFocused: false,
            isFindOnPagePresented: false,
            isSettingsPresented: false,
            isPrivateBrowsingEnabled: false,
            hasRecentlyClosedTabs: false
        )

        let resolution = router.route(.focusAddressBar, in: context)
        XCTAssertTrue(resolution.isHandled)
        XCTAssertEqual(resolution.effects, [.setTabOverviewVisible(false), .focusAddressBar(selectAll: true)])
    }

    func testCloseWhileOverviewVisibleClosesOverviewSelection() {
        let router = SceneCommandRouter()
        let activeID = UUID()
        let selectedID = UUID()
        let context = CommandContextSnapshot(
            tabCount: 3,
            activeTabID: activeID,
            tabOverviewSelectedTabID: selectedID,
            isTabOverviewVisible: true,
            isAddressBarFocused: false,
            isFindOnPagePresented: false,
            isSettingsPresented: false,
            isPrivateBrowsingEnabled: false,
            hasRecentlyClosedTabs: false
        )

        let resolution = router.route(.close, in: context)
        XCTAssertTrue(resolution.isHandled)
        XCTAssertEqual(resolution.effects, [.closeTab(id: selectedID)])
    }

    func testCloseWhileOverviewNotVisibleClosesActiveTab() {
        let router = SceneCommandRouter()
        let activeID = UUID()
        let context = CommandContextSnapshot(
            tabCount: 3,
            activeTabID: activeID,
            tabOverviewSelectedTabID: nil,
            isTabOverviewVisible: false,
            isAddressBarFocused: false,
            isFindOnPagePresented: false,
            isSettingsPresented: false,
            isPrivateBrowsingEnabled: false,
            hasRecentlyClosedTabs: false
        )

        let resolution = router.route(.close, in: context)
        XCTAssertTrue(resolution.isHandled)
        XCTAssertEqual(resolution.effects, [.closeTab(id: activeID)])
    }

    func testReopenLastClosedTabUnhandledWhenNone() {
        let router = SceneCommandRouter()
        let context = CommandContextSnapshot(
            tabCount: 1,
            activeTabID: UUID(),
            tabOverviewSelectedTabID: nil,
            isTabOverviewVisible: false,
            isAddressBarFocused: false,
            isFindOnPagePresented: false,
            isSettingsPresented: false,
            isPrivateBrowsingEnabled: false,
            hasRecentlyClosedTabs: false
        )

        let resolution = router.route(.reopenLastClosedTab, in: context)
        XCTAssertFalse(resolution.isHandled)
        XCTAssertEqual(resolution.effects, [])
    }

    func testReopenLastClosedTabRoutesWhenAvailable() {
        let router = SceneCommandRouter()
        let context = CommandContextSnapshot(
            tabCount: 1,
            activeTabID: UUID(),
            tabOverviewSelectedTabID: nil,
            isTabOverviewVisible: false,
            isAddressBarFocused: false,
            isFindOnPagePresented: false,
            isSettingsPresented: false,
            isPrivateBrowsingEnabled: false,
            hasRecentlyClosedTabs: true
        )

        let resolution = router.route(.reopenLastClosedTab, in: context)
        XCTAssertTrue(resolution.isHandled)
        XCTAssertEqual(resolution.effects, [.reopenLastClosedTab])
    }

    func testSelectTabByNumberUnhandledWithNoTabs() {
        let router = SceneCommandRouter()
        let context = CommandContextSnapshot(
            tabCount: 0,
            activeTabID: nil,
            tabOverviewSelectedTabID: nil,
            isTabOverviewVisible: false,
            isAddressBarFocused: false,
            isFindOnPagePresented: false,
            isSettingsPresented: false,
            isPrivateBrowsingEnabled: false,
            hasRecentlyClosedTabs: false
        )

        let resolution = router.route(.selectTabByNumber(1), in: context)
        XCTAssertFalse(resolution.isHandled)
    }
}
