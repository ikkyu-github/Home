import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class BrowserSessionStoreNavigationTests: XCTestCase {

    func testWindowSessionStateRoundTripPersistsTabNavigationByID() throws {
        let tabID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let tab = BrowserTab(id: tabID, title: "A", urlString: "https://a.com")

        let nav = TabNavigationState(
            entries: [
                NavigationEntry(urlString: "https://a.com", title: "A"),
                NavigationEntry(urlString: "https://b.com", title: "B")
            ],
            cursor: .init(index: 1),
            pending: .goToIndex(0)
        )

        let snapshot = WindowSessionState(
            tabs: [tab],
            selectedTabID: tabID,
            tabGroups: [],
            selectedTabGroupID: nil,
            tabNavigationByID: [tabID: nav]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WindowSessionState.self, from: data)

        XCTAssertEqual(decoded.tabs.map(\.id), [tabID])
        XCTAssertEqual(decoded.selectedTabID, tabID)

        let decodedNav = try XCTUnwrap(decoded.tabNavigationByID[tabID])
        XCTAssertEqual(decodedNav.entries.map(\.urlString), ["https://a.com", "https://b.com"])
        XCTAssertEqual(decodedNav.cursor?.index, 1)
        XCTAssertNil(decodedNav.pending)
    }

    @MainActor
    func testGoBackSetsPendingAndCommitReconcilesCursorWithoutRewritingHistory() async {
        let store = BrowserSessionStore(persistence: .memory)
        await store.awaitInitialLoad()

        let tabID = try! XCTUnwrap(store.selectedTabID)

        store.applyWebKitCommit(tabID: tabID, context: .init(urlString: "https://a.com", title: "A"))
        store.applyWebKitCommit(tabID: tabID, context: .init(urlString: "https://b.com", title: "B"))
        store.applyWebKitCommit(tabID: tabID, context: .init(urlString: "https://c.com", title: "C"))

        XCTAssertTrue(store.canGoBack(tabID: tabID))
        XCTAssertFalse(store.canGoForward(tabID: tabID))

        let target = store.requestGoBack(tabID: tabID)
        XCTAssertEqual(target, "https://b.com")

        let pendingAfterRequest = store.tabNavigationByID[tabID]?.pending
        XCTAssertEqual(pendingAfterRequest, .goToIndex(1))

        store.applyWebKitCommit(tabID: tabID, context: .init(urlString: "https://b.com", title: "B"))

        let reconciled = store.tabNavigationByID[tabID]
        XCTAssertEqual(reconciled?.entries.map(\.urlString), ["https://a.com", "https://b.com", "https://c.com"])
        XCTAssertEqual(reconciled?.cursor?.index, 1)
        XCTAssertNil(reconciled?.pending)
    }

    @MainActor
    func testGoBackAtStartReturnsNil() async {
        let store = BrowserSessionStore(persistence: .memory)
        await store.awaitInitialLoad()
        let tabID = try! XCTUnwrap(store.selectedTabID)

        store.applyWebKitCommit(tabID: tabID, context: .init(urlString: "https://a.com"))
        XCTAssertFalse(store.canGoBack(tabID: tabID))
        XCTAssertNil(store.requestGoBack(tabID: tabID))
    }
}
