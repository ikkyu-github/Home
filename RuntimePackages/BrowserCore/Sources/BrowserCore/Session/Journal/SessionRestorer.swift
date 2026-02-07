import Foundation

public struct SessionRestorePlan: Sendable {
    public var initialState: SessionState
    public var deferredNavigationTabIDs: [UUID]

    public init(initialState: SessionState, deferredNavigationTabIDs: [UUID]) {
        self.initialState = initialState
        self.deferredNavigationTabIDs = deferredNavigationTabIDs
    }
}

/// Deterministic journal replayer.
///
/// Strategy:
/// - Read append-only journal events (including archived segments)
/// - Provide a UI-first plan: structure now, navigation later
public actor SessionRestorer {

    public init() {}

    public func replayJournal(journalID: String) async -> SessionRestorePlan? {
        let journal = SessionJournal(journalID: journalID)

        let base = SessionState(windows: [])
        let events = await journal.readAllEventsIncludingArchives()
        guard events.isEmpty == false else { return nil }

        // Pure deterministic replay (no UI/WebKit side effects).
        let engine = SessionReplayEngine()
        let output = engine.replay(baseState: base, events: events, policy: SessionReplayPolicy())
        return output.plan
    }
}
