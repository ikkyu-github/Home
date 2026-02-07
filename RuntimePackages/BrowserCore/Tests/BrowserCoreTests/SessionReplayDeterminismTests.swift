import XCTest
@testable import BrowserCore

final class SessionReplayDeterminismTests: XCTestCase {

    private func encodeState(_ state: SessionState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }

    private func lifecycle(of tabID: UUID, in state: SessionState) -> TabState.LifecycleState? {
        for w in state.windows {
            for p in w.panes {
                if let t = p.tabOrder.first(where: { $0.tabID == tabID }) {
                    return t.lifecycleState
                }
            }
        }
        return nil
    }

    func testReplaySameEventsTwiceProducesSameStateForAllFields() throws {
        let engine = SessionReplayEngine()
        let base = SessionState(windows: [])

        let tabA = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
        let tabB = UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!
        let t = Date(timeIntervalSince1970: 100)

        let events: [SessionJournalEvent] = [
            SessionJournalEvent(type: .windowCreated, timestamp: t, windowID: "default", eventID: UUID(uuidString: "00000000-0000-0000-0000-000000001001")!),
            SessionJournalEvent(type: .splitModeChanged, timestamp: t, windowID: "default", paneID: "left", eventID: UUID(uuidString: "00000000-0000-0000-0000-000000001002")!),

            SessionJournalEvent(type: .tabCreated, timestamp: t, windowID: "default", paneID: "left", tabID: tabA, eventID: UUID(uuidString: "00000000-0000-0000-0000-000000001003")!),
            SessionJournalEvent(type: .tabCreated, timestamp: t, windowID: "default", paneID: "right", tabID: tabB, eventID: UUID(uuidString: "00000000-0000-0000-0000-000000001004")!),

            SessionJournalEvent(type: .tabSelected, timestamp: t, windowID: "default", paneID: "left", tabID: tabA, eventID: UUID(uuidString: "00000000-0000-0000-0000-000000001005")!),
            SessionJournalEvent(type: .paneFocusChanged, timestamp: t, windowID: "default", paneID: "left", eventID: UUID(uuidString: "00000000-0000-0000-0000-000000001006")!),

            SessionJournalEvent(type: .navigationCommitted, timestamp: t, windowID: "default", paneID: "left", tabID: tabA, url: "https://example.com/a", eventID: UUID(uuidString: "00000000-0000-0000-0000-000000001007")!),
            SessionJournalEvent(type: .navigationCommitted, timestamp: t, windowID: "default", paneID: "right", tabID: tabB, url: "https://example.com/b", eventID: UUID(uuidString: "00000000-0000-0000-0000-000000001008")!),
            SessionJournalEvent(type: .tabSuspended, timestamp: t, windowID: "default", paneID: "left", tabID: tabA, eventID: UUID(uuidString: "00000000-0000-0000-0000-000000001009")!)
        ]

        let out1 = engine.replay(baseState: base, events: events, policy: SessionReplayPolicy(ordering: ReplayOrderingPolicy(mode: .sortByDeterministicKey)))
        let out2 = engine.replay(baseState: base, events: events, policy: SessionReplayPolicy(ordering: ReplayOrderingPolicy(mode: .sortByDeterministicKey)))

        XCTAssertEqual(try encodeState(out1.plan.initialState), try encodeState(out2.plan.initialState))
        XCTAssertEqual(out1.plan.deferredNavigationTabIDs, out2.plan.deferredNavigationTabIDs)

        XCTAssertEqual(lifecycle(of: tabA, in: out1.plan.initialState), .frozen)
    }

    func testOutOfOrderInputsReplayToSameStateAfterDeterministicSort() throws {
        let engine = SessionReplayEngine()
        let base = SessionState(windows: [])

        let tabA = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        let tabB = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
        let t = Date(timeIntervalSince1970: 200)

        // Same timestamp to force the deterministic-key sorter to rely on phase weight + eventID.
        let canonical: [SessionJournalEvent] = [
            SessionJournalEvent(type: .splitModeChanged, timestamp: t, windowID: "default", paneID: "left", eventID: UUID(uuidString: "00000000-0000-0000-0000-000000002001")!),
            SessionJournalEvent(type: .tabCreated, timestamp: t, windowID: "default", paneID: "left", tabID: tabA, eventID: UUID(uuidString: "00000000-0000-0000-0000-000000002002")!),
            SessionJournalEvent(type: .tabCreated, timestamp: t, windowID: "default", paneID: "right", tabID: tabB, eventID: UUID(uuidString: "00000000-0000-0000-0000-000000002003")!),
            SessionJournalEvent(type: .tabSelected, timestamp: t, windowID: "default", paneID: "left", tabID: tabA, eventID: UUID(uuidString: "00000000-0000-0000-0000-000000002004")!),
            SessionJournalEvent(type: .paneFocusChanged, timestamp: t, windowID: "default", paneID: "left", eventID: UUID(uuidString: "00000000-0000-0000-0000-000000002005")!),
            SessionJournalEvent(type: .navigationCommitted, timestamp: t, windowID: "default", paneID: "left", tabID: tabA, url: "https://example.com/a", eventID: UUID(uuidString: "00000000-0000-0000-0000-000000002006")!),
            SessionJournalEvent(type: .navigationCommitted, timestamp: t, windowID: "default", paneID: "right", tabID: tabB, url: "https://example.com/b", eventID: UUID(uuidString: "00000000-0000-0000-0000-000000002007")!),
            SessionJournalEvent(type: .tabDiscarded, timestamp: t, windowID: "default", paneID: "right", tabID: tabB, eventID: UUID(uuidString: "00000000-0000-0000-0000-000000002008")!)
        ]

        let policy = SessionReplayPolicy(ordering: ReplayOrderingPolicy(mode: .sortByDeterministicKey))

        let reference = engine.replay(baseState: base, events: canonical, policy: policy)
        let referenceState = try encodeState(reference.plan.initialState)
        let referenceDeferred = reference.plan.deferredNavigationTabIDs

        // A few representative permutations (reverse, rotate, interleave) to simulate out-of-order journal tails.
        let reversed = Array(canonical.reversed())
        let rotated = Array(canonical.dropFirst(2) + canonical.prefix(2))
        let interleaved: [SessionJournalEvent] = [canonical[3], canonical[6], canonical[0], canonical[5], canonical[1], canonical[4], canonical[2], canonical[7]]

        for candidate in [reversed, rotated, interleaved] {
            let out = engine.replay(baseState: base, events: candidate, policy: policy)
            XCTAssertEqual(try encodeState(out.plan.initialState), referenceState)
            XCTAssertEqual(out.plan.deferredNavigationTabIDs, referenceDeferred)
        }

        XCTAssertEqual(lifecycle(of: tabB, in: reference.plan.initialState), .evicted)
    }
}
