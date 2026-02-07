import Foundation
import SafariLikeContracts

public struct SessionReplayEngine: Sendable {

    public struct Output: Sendable {
        public var plan: SessionRestorePlan
        public var diagnostics: ReplayDiagnostics

        public init(plan: SessionRestorePlan, diagnostics: ReplayDiagnostics) {
            self.plan = plan
            self.diagnostics = diagnostics
        }
    }

    public init() {}

    public func replay(
        baseState: SessionState,
        events inputEvents: [SessionJournalEvent],
        policy: SessionReplayPolicy = SessionReplayPolicy()
    ) -> Output {
        var diagnostics = ReplayDiagnostics()

        // Best-effort migration scaffold.
        let olderEvents = inputEvents.filter { $0.schemaVersion < SessionJournalEvent.currentSchemaVersion }
        if !olderEvents.isEmpty {
            diagnostics.migrationsApplied += olderEvents.count
            diagnostics.info("Applied no-op migration for older event schema versions")
        }

        let events: [SessionJournalEvent]
        switch policy.ordering.mode {
        case .sortByDeterministicKey:
            events = Self.sortedDeterministically(inputEvents)
            if events.map(\.eventID) != inputEvents.map(\.eventID) {
                diagnostics.outOfOrderEventsDetected += 1
            }
        case .trustInputOrder:
            events = inputEvents
            diagnostics.outOfOrderEventsDetected += Self.outOfOrderCount(events)
        }

        var state = baseState
        if state.windows.isEmpty {
            state.windows = [SessionReducer.makeDefaultWindowState()]
        }
        var reducer = SessionReducer()
        var urlByTabID: [UUID: URL] = [:]

        for event in events {
            reducer.apply(event, state: &state, urlByTabID: &urlByTabID, diagnostics: &diagnostics, policy: policy)
        }

        let plan = SessionRestorePlan(initialState: state, deferredNavigationTabIDs: Self.deferredTabs(for: state))

        #if DEBUG
        ReplayDiagnosticsLogger.debug("Replay complete: dropped=\(diagnostics.droppedEvents), placeholders=\(diagnostics.placeholderTabsCreated), outOfOrder=\(diagnostics.outOfOrderEventsDetected)")
        #endif

        return Output(plan: plan, diagnostics: diagnostics)
    }

    private static func sortedDeterministically(_ events: [SessionJournalEvent]) -> [SessionJournalEvent] {
        func phaseWeight(for type: SessionJournalEventType) -> Int {
            switch type {
            // Structural: create tabs/panes first.
            case .appLaunched,
                 .sessionStarted,
                 .windowCreated,
                 .windowClosed,
                 .paneCreated,
                 .splitModeChanged,
                 .tabCreated,
                 .tabMovedPane,
                 .tabReordered,
                 .tabClosed:
                return 0

            // Focus/selection: establish active pane/tab before navigation.
            case .paneSelected,
                 .paneFocusChanged,
                 .paneFocused,
                 .tabSelected:
                return 1

            // Navigation commit: safe to apply after selection is stable.
            case .navigationCommitted,
                 .urlCommitted,
                 .tabSuspended,
                 .tabDiscarded:
                return 2

            // UI visibility: treated as best-effort telemetry.
            case .sidebarToggled,
                 .relatedToggled,
                 .overviewToggled,
                 .tabPinned,
                 .tabMuted,
                 .renderPolicyChanged,
                 .snapshotCreated:
                return 3

            // Policy decisions are telemetry; keep late.
            case .policyDecision:
                return 4

            // Restore marker last.
            case .restoreCompleted:
                return 5

            // Unknown/future/legacy: keep stable but low priority.
            case .paneEnteredSplit, .paneExitedSplit:
                return 0

            @unknown default:
                return 6
            }
        }

        return events.sorted { a, b in
            if a.createdAt != b.createdAt {
                return a.createdAt < b.createdAt
            }

            let pa = phaseWeight(for: a.type)
            let pb = phaseWeight(for: b.type)
            if pa != pb {
                return pa < pb
            }

            // UUID has no natural ordering; uuidString is stable and deterministic.
            return a.eventID.uuidString < b.eventID.uuidString
        }
    }

    private static func outOfOrderCount(_ events: [SessionJournalEvent]) -> Int {
        guard events.count >= 2 else { return 0 }
        var count = 0
        var last = (events[0].createdAt, events[0].eventID.uuidString)
        for e in events.dropFirst() {
            let key = (e.createdAt, e.eventID.uuidString)
            if key.0 < last.0 || (key.0 == last.0 && key.1 < last.1) {
                count += 1
            }
            last = key
        }
        return count
    }

    private static func deferredTabs(for state: SessionState) -> [UUID] {
        guard let w = state.windows.first else { return [] }
        let visible = Set(w.panes.compactMap { $0.activeTabID })

        var deferred: [UUID] = []
        for pane in w.panes {
            for tab in pane.tabOrder {
                if !visible.contains(tab.tabID) {
                    deferred.append(tab.tabID)
                }
            }
        }
        return deferred
    }
}
