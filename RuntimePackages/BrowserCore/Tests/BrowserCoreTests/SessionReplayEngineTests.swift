import XCTest
@testable import BrowserCore

final class SessionReplayEngineTests: XCTestCase {

    private func encodeState(_ state: SessionState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }

    func testDeterministicSortProducesSameState() throws {
        let t1 = Date(timeIntervalSince1970: 1)
        let t2 = Date(timeIntervalSince1970: 2)
        let tabA = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
        let tabB = UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!

        let e1 = SessionJournalEvent(
            type: .tabCreated,
            timestamp: t1,
            windowID: "default",
            paneID: "left",
            tabID: tabA,
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        let e2 = SessionJournalEvent(
            type: .tabCreated,
            timestamp: t2,
            windowID: "default",
            paneID: "left",
            tabID: tabB,
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        )

        let base = SessionState(windows: [])
        let engine = SessionReplayEngine()

        let sortedPolicy = SessionReplayPolicy(ordering: ReplayOrderingPolicy(mode: .sortByDeterministicKey), errorPolicy: .createPlaceholderTab)

        let out1 = engine.replay(baseState: base, events: [e2, e1], policy: sortedPolicy)
        let out2 = engine.replay(baseState: base, events: [e1, e2], policy: sortedPolicy)

        XCTAssertEqual(out1.plan.initialState.windows.count, 1)
        XCTAssertEqual(try encodeState(out1.plan.initialState), try encodeState(out2.plan.initialState))
        XCTAssertGreaterThanOrEqual(out1.diagnostics.outOfOrderEventsDetected, 1)
    }

    func testTabClosedFallsBackSelectionAndActiveTab() throws {
        let t1 = Date(timeIntervalSince1970: 1)
        let t2 = Date(timeIntervalSince1970: 2)
        let t3 = Date(timeIntervalSince1970: 3)

        let tabA = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let tabB = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!

        let createA = SessionJournalEvent(type: .tabCreated, timestamp: t1, windowID: "default", paneID: "left", tabID: tabA, eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!)
        let createB = SessionJournalEvent(type: .tabCreated, timestamp: t2, windowID: "default", paneID: "left", tabID: tabB, eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!)
        let selectB = SessionJournalEvent(type: .tabSelected, timestamp: t2, windowID: "default", paneID: "left", tabID: tabB, eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000022")!)
        let closeB = SessionJournalEvent(type: .tabClosed, timestamp: t3, windowID: "default", paneID: "left", tabID: tabB, eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000023")!)

        let engine = SessionReplayEngine()
        let out = engine.replay(baseState: SessionState(windows: []), events: [createA, createB, selectB, closeB])

        let window = try XCTUnwrap(out.plan.initialState.windows.first)
        XCTAssertEqual(window.panes.count, 1)
        XCTAssertEqual(window.panes[0].tabOrder.map(\.tabID), [tabA])
        XCTAssertEqual(window.panes[0].activeTabID, tabA)
        XCTAssertEqual(window.selectedTabID, tabA)
    }

    func testEmptyBaseStateUsesDeterministicDefaultWindowID() {
        let base = SessionState(windows: [])
        let engine = SessionReplayEngine()

        let policy = SessionReplayPolicy(ordering: ReplayOrderingPolicy(mode: .sortByDeterministicKey))
        let out = engine.replay(baseState: base, events: [], policy: policy)

        XCTAssertEqual(out.plan.initialState.windows.count, 1)
        XCTAssertEqual(out.plan.initialState.windows.first?.id.uuidString, "00000000-0000-0000-0000-000000000001")
    }

    func testSplitModeCreatesSecondPaneAndTargetsSecondary() throws {
        let t1 = Date(timeIntervalSince1970: 1)
        let tabRight = UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!

        let split = SessionJournalEvent(
            type: .splitModeChanged,
            timestamp: t1,
            windowID: "default",
            paneID: "left",
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        )

        let createSecondary = SessionJournalEvent(
            type: .tabCreated,
            timestamp: t1,
            windowID: "default",
            paneID: "right",
            tabID: tabRight,
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        )

        let engine = SessionReplayEngine()
        let out = engine.replay(baseState: SessionState(windows: []), events: [split, createSecondary])

        let window = try XCTUnwrap(out.plan.initialState.windows.first)
        XCTAssertEqual(window.panes.count, 2)
        XCTAssertEqual(window.panes[1].activeTabID, tabRight)
        XCTAssertEqual(window.selectedTabID, tabRight)
    }

    func testPaneExitedSplitCollapsesToSinglePane() throws {
        let t1 = Date(timeIntervalSince1970: 1)
        let t2 = Date(timeIntervalSince1970: 2)

        let enter = SessionJournalEvent(
            type: .splitModeChanged,
            timestamp: t1,
            windowID: "default",
            paneID: "left",
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
        )

        let exit = SessionJournalEvent(
            type: .paneExitedSplit,
            timestamp: t2,
            windowID: "default",
            paneID: "left",
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000302")!
        )

        let engine = SessionReplayEngine()
        let out = engine.replay(baseState: SessionState(windows: []), events: [enter, exit])

        let window = try XCTUnwrap(out.plan.initialState.windows.first)
        XCTAssertEqual(window.panes.count, 1)
    }

    func testUrlCommittedMissingTabCreatesPlaceholderOrDrops() throws {
        let tab = UUID(uuidString: "00000000-0000-0000-0000-0000000000CC")!
        let t1 = Date(timeIntervalSince1970: 1)

        let commit = SessionJournalEvent(
            type: .urlCommitted,
            timestamp: t1,
            windowID: "default",
            paneID: "left",
            tabID: tab,
            url: "https://example.com",
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
        )

        let engine = SessionReplayEngine()

        let createPolicy = SessionReplayPolicy(ordering: ReplayOrderingPolicy(mode: .sortByDeterministicKey), errorPolicy: .createPlaceholderTab)
        let created = engine.replay(baseState: SessionState(windows: []), events: [commit], policy: createPolicy)

        let window1 = try XCTUnwrap(created.plan.initialState.windows.first)
        XCTAssertEqual(window1.panes.first?.tabOrder.first?.tabID, tab)
        XCTAssertEqual(window1.panes.first?.tabOrder.first?.url.absoluteString, "https://example.com")
        XCTAssertEqual(created.diagnostics.placeholderTabsCreated, 1)

        let dropPolicy = SessionReplayPolicy(ordering: ReplayOrderingPolicy(mode: .sortByDeterministicKey), errorPolicy: .dropInvalidEvent)
        let dropped = engine.replay(baseState: SessionState(windows: []), events: [commit], policy: dropPolicy)

        let window2 = try XCTUnwrap(dropped.plan.initialState.windows.first)
        XCTAssertTrue(window2.panes.first?.tabOrder.isEmpty ?? true)
        XCTAssertEqual(dropped.diagnostics.droppedEvents, 1)
    }
}
