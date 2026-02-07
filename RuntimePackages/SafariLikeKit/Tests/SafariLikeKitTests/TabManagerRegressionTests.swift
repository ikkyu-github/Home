import XCTest
@testable import SafariLikeKit

final class TabManagerRegressionTests: XCTestCase {
    func testOpenNewTabSelectsNewTab() {
        let manager = TabManager()
        let newTabID = manager.openNewTab()
        XCTAssertEqual(manager.selectedTabID, newTabID)
    }

    func testCloseTabSelectsNextTab() {
        let manager = TabManager()
        let tab1 = manager.openNewTab()
        let tab2 = manager.openNewTab()
        manager.closeTab(tab1)
        XCTAssertEqual(manager.selectedTabID, tab2)
    }

    func testRapidTabSwitchingKeepsStateConsistent() {
        let manager = TabManager()
        let tabIDs = (0..<5).map { _ in manager.openNewTab() }
        for id in tabIDs.reversed() {
            manager.selectTab(id)
        }
        XCTAssertEqual(manager.selectedTabID, tabIDs.first)
    }
}
