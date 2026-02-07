import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class BrowserSessionStoreTabManagementTests: XCTestCase {

    @MainActor
    func testCloseTabRecordsRecentlyClosedAndUndoRestoresTabAndNav() async {
        let store = BrowserSessionStore(persistence: .memory)
        await store.awaitInitialLoad()

        let firstID = try! XCTUnwrap(store.selectedTabID)

        // Give the first tab some durable navigation.
        store.applyWebKitCommit(tabID: firstID, context: .init(urlString: "https://a.com", title: "A"))
        store.applyWebKitCommit(tabID: firstID, context: .init(urlString: "https://b.com", title: "B"))
        let navBeforeClose = store.tabNavigationByID[firstID]
        XCTAssertEqual(navBeforeClose?.entries.map(\.urlString), ["https://a.com", "https://b.com"])

        // Close the selected tab.
        store.closeTab(id: firstID)

        XCTAssertEqual(store.recentlyClosed.count, 1)
        XCTAssertEqual(store.recentlyClosed.first?.tab.id, firstID)
        XCTAssertEqual(store.recentlyClosed.first?.navigation?.entries.map(\.urlString), ["https://a.com", "https://b.com"])

        // Undo close should restore the tab and its nav state and select it.
        let restoredID = store.undoCloseLastTab()
        XCTAssertEqual(restoredID, firstID)
        XCTAssertEqual(store.selectedTabID, firstID)
        XCTAssertTrue(store.tabs.contains(where: { $0.id == firstID }))

        let navAfterUndo = store.tabNavigationByID[firstID]
        XCTAssertEqual(navAfterUndo?.entries.map(\.urlString), ["https://a.com", "https://b.com"])
        XCTAssertEqual(store.recentlyClosed.count, 0)
    }

    @MainActor
    func testCloseTabRemovesFromGroupTabIDs() async {
        let store = BrowserSessionStore(persistence: .memory)
        await store.awaitInitialLoad()

        let tabID = try! XCTUnwrap(store.selectedTabID)
        let groupID = store.createTabGroup(name: "G", color: .blue)
        store.addTabToGroup(tabID: tabID, groupID: groupID)

        XCTAssertTrue(store.tabGroups.contains(where: { $0.id == groupID && $0.tabIDs.contains(tabID) }))

        store.closeTab(id: tabID)

        let group = store.tabGroups.first(where: { $0.id == groupID })
        XCTAssertNotNil(group)
        XCTAssertFalse(group?.tabIDs.contains(tabID) ?? true)
    }

    @MainActor
    func testPinnedTabsStayInFrontAndCannotBeReorderedPastBoundary() async {
        let store = BrowserSessionStore(persistence: .memory)
        await store.awaitInitialLoad()

        let pinnedID = try! XCTUnwrap(store.selectedTabID)
        store.updateTab(id: pinnedID, isPinned: true)

        let newID = store.addTab()
        XCTAssertEqual(store.tabs.map(\.id), [pinnedID, newID])

        // Attempt to move unpinned tab into pinned segment.
        store.moveTab(from: 1, to: 0)
        XCTAssertEqual(store.tabs.map(\.id), [pinnedID, newID])

        // Attempt to move pinned tab into unpinned segment.
        store.moveTab(from: 0, to: 1)
        XCTAssertEqual(store.tabs.map(\.id), [pinnedID, newID])
    }

    func testWindowSessionStateRoundTripPersistsRecentlyClosed() throws {
        let tabID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let tab = BrowserTab(id: tabID, title: "A", urlString: "https://a.com")
        let nav = TabNavigationState(entries: [NavigationEntry(urlString: "https://a.com", title: "A")], cursor: .init(index: 0))

        let snapshot = WindowSessionState(
            tabs: [tab],
            selectedTabID: tabID,
            tabGroups: [],
            selectedTabGroupID: nil,
            recentlyClosed: [.init(tab: tab, navigation: nav, closedAt: Date(timeIntervalSince1970: 1), originalIndex: 0)],
            tabNavigationByID: [tabID: nav]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WindowSessionState.self, from: data)

        XCTAssertEqual(decoded.recentlyClosed.count, 1)
        XCTAssertEqual(decoded.recentlyClosed.first?.tab.id, tabID)
        XCTAssertEqual(decoded.recentlyClosed.first?.navigation?.entries.map(\.urlString), ["https://a.com"])
        XCTAssertEqual(decoded.recentlyClosed.first?.originalIndex, 0)
    }
}
