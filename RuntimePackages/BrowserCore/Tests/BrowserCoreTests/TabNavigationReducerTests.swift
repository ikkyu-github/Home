import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class TabNavigationReducerTests: XCTestCase {

    func testRedirectCommitReplacesCurrentEntry() {
        var state = TabNavigationState()
        state = TabNavigationReducer.reduce(state, event: .webKitDidCommit(.init(urlString: "https://example.com/a", title: "A")))
        XCTAssertEqual(state.entries.count, 1)
        XCTAssertEqual(state.currentEntry?.urlString, "https://example.com/a")

        state = TabNavigationReducer.reduce(
            state,
            event: .webKitDidCommit(.init(urlString: "https://example.com/b", title: "B", kind: .redirect, redirectDepth: 1))
        )
        XCTAssertEqual(state.entries.count, 1)
        XCTAssertEqual(state.currentEntry?.urlString, "https://example.com/b")
        XCTAssertEqual(state.currentEntry?.title, "B")
    }

    func testGoToIndexPendingMovesCursorWithoutRewritingHistory() {
        var state = TabNavigationState()
        for u in ["https://a.com", "https://b.com", "https://c.com"] {
            state = TabNavigationReducer.reduce(state, event: .webKitDidCommit(.init(urlString: u)))
        }
        XCTAssertEqual(state.entries.map(\.urlString), ["https://a.com", "https://b.com", "https://c.com"])
        XCTAssertEqual(state.cursor?.index, 2)

        state = TabNavigationReducer.reduce(state, event: .userRequestedGoToIndex(1))
        state = TabNavigationReducer.reduce(state, event: .webKitDidCommit(.init(urlString: "https://b.com")))

        XCTAssertEqual(state.cursor?.index, 1)
        XCTAssertNil(state.pending)
        XCTAssertEqual(state.entries.map(\.urlString), ["https://a.com", "https://b.com", "https://c.com"])
    }

    func testPendingIntentIsNotPersisted() throws {
        let original = TabNavigationState(
            entries: [NavigationEntry(urlString: "https://a.com")],
            cursor: .init(index: 0),
            pending: .goToIndex(0)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TabNavigationState.self, from: data)
        XCTAssertNil(decoded.pending)
        XCTAssertEqual(decoded.entries, original.entries)
        XCTAssertEqual(decoded.cursor, original.cursor)
    }

    func testBoundedHistoryTrimsOldestAndAdjustsCursor() {
        var state = TabNavigationState()
        for i in 0..<5 {
            state = TabNavigationReducer.reduce(state, event: .webKitDidCommit(.init(urlString: "https://e.com/\(i)")), maxEntries: 3)
        }
        XCTAssertEqual(state.entries.count, 3)
        XCTAssertEqual(state.entries.map(\.urlString), ["https://e.com/2", "https://e.com/3", "https://e.com/4"])
        XCTAssertEqual(state.cursor?.index, 2)
        XCTAssertEqual(state.currentEntry?.urlString, "https://e.com/4")
    }
}
