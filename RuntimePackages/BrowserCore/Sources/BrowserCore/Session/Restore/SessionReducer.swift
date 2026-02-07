import Foundation
import SafariLikeContracts

public struct SessionReducer: Sendable {

    static let defaultWindowUUID: UUID = {
        let raw = "00000000-0000-0000-0000-000000000001"
        guard let uuid = UUID(uuidString: raw) else {
            assertionFailure("Invalid hardcoded default window UUID: \(raw)")
            // Deterministic fallback (valid UUID string).
            return UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        }
        return uuid
    }()

    static func makeDefaultWindowState() -> WindowState {
        WindowState(
            id: defaultWindowUUID,
            selectedTabID: nil,
            panes: [PaneState(activeTabID: nil, tabOrder: [])]
        )
    }

    public init() {}

    public mutating func apply(
        _ event: SessionJournalEvent,
        state: inout SessionState,
        urlByTabID: inout [UUID: URL],
        diagnostics: inout ReplayDiagnostics,
        policy: SessionReplayPolicy
    ) {
        if state.windows.isEmpty {
            state.windows = [Self.makeDefaultWindowState()]
        }

        // Current persistence format only meaningfully supports a single window.
        // Keep deterministic behavior by applying all events to window 0.
        let w = 0

        if event.windowID != "default" {
            diagnostics.warn("Non-default windowID was ignored: \(event.windowID)", eventID: event.eventID)
        }

        func paneIndex(for paneID: String?) -> Int {
            guard let paneID else { return 0 }
            switch paneID {
            case "secondary", "right":
                return 1
            default:
                return 0
            }
        }

        func ensureSplit(_ isSplit: Bool) {
            if isSplit {
                if state.windows[w].panes.count < 2 {
                    state.windows[w].panes = [
                        state.windows[w].panes.first ?? PaneState(activeTabID: nil, tabOrder: []),
                        PaneState(activeTabID: nil, tabOrder: [])
                    ]
                }
            } else {
                if state.windows[w].panes.count > 1 {
                    state.windows[w].panes = [state.windows[w].panes.first ?? PaneState(activeTabID: nil, tabOrder: [])]
                }
            }
        }

        func tabExists(_ tabID: UUID) -> Bool {
            state.windows[w].panes.contains { pane in
                pane.tabOrder.contains(where: { $0.tabID == tabID })
            }
        }

        func createPlaceholderTab(tabID: UUID, pane: Int) {
            ensureSplit(pane == 1)
            if tabExists(tabID) {
                return
            }

            let placeholder = TabState(tabID: tabID, url: DefaultURLs.aboutBlank, title: nil, lifecycleState: .frozen)
            state.windows[w].panes[pane].tabOrder.append(placeholder)
            if state.windows[w].panes[pane].activeTabID == nil {
                state.windows[w].panes[pane].activeTabID = tabID
            }
            if state.windows[w].selectedTabID == nil {
                state.windows[w].selectedTabID = tabID
            }

            diagnostics.placeholderTabsCreated += 1
            diagnostics.warn("Created placeholder tab for missing tabID", eventID: event.eventID)
        }

        func normalizeSelections() {
            // Ensure activeTabID points to an existing tab if possible.
            for p in state.windows[w].panes.indices {
                if let active = state.windows[w].panes[p].activeTabID {
                    if state.windows[w].panes[p].tabOrder.contains(where: { $0.tabID == active }) == false {
                        state.windows[w].panes[p].activeTabID = state.windows[w].panes[p].tabOrder.first?.tabID
                    }
                } else if state.windows[w].panes[p].tabOrder.isEmpty == false {
                    state.windows[w].panes[p].activeTabID = state.windows[w].panes[p].tabOrder.first?.tabID
                }
            }

            if let selected = state.windows[w].selectedTabID {
                let exists = state.windows[w].panes.contains { $0.tabOrder.contains(where: { $0.tabID == selected }) }
                if !exists {
                    state.windows[w].selectedTabID = state.windows[w].panes.first?.activeTabID
                }
            } else {
                state.windows[w].selectedTabID = state.windows[w].panes.first?.activeTabID
            }
        }

        func reorderTab(inPane p: Int, fromIndex: Int, toIndex: Int) {
            guard state.windows[w].panes.indices.contains(p) else { return }
            var order = state.windows[w].panes[p].tabOrder
            guard fromIndex >= 0, fromIndex < order.count else {
                diagnostics.droppedEvents += 1
                diagnostics.warn("Dropped tabReordered with out-of-range fromIndex", eventID: event.eventID)
                return
            }
            guard toIndex >= 0, toIndex < order.count else {
                diagnostics.droppedEvents += 1
                diagnostics.warn("Dropped tabReordered with out-of-range toIndex", eventID: event.eventID)
                return
            }
            if fromIndex == toIndex { return }

            let item = order.remove(at: fromIndex)
            order.insert(item, at: toIndex)
            state.windows[w].panes[p].tabOrder = order
        }

        switch event.type {
        case .appLaunched, .sessionStarted, .restoreCompleted:
            break

        case .policyDecision:
            // Policy decisions are telemetry; they should not affect replayed session state.
            break

        case .windowCreated:
            if state.windows.isEmpty {
                state.windows = [Self.makeDefaultWindowState()]
            }

        case .windowClosed:
            // Single-window persistence: treat closing as clearing session content.
            // Keep a single deterministic window container for subsequent events.
            let existingTabIDs = state.windows[w].panes.flatMap { $0.tabOrder.map(\.tabID) }
            for id in existingTabIDs {
                urlByTabID.removeValue(forKey: id)
            }
            state.windows[w].selectedTabID = nil
            state.windows[w].panes = [PaneState(activeTabID: nil, tabOrder: [])]

        case .paneCreated:
            let p = paneIndex(for: event.paneID)
            ensureSplit(p == 1)

        case .paneEnteredSplit, .splitModeChanged:
            if event.type == .paneEnteredSplit {
                ensureSplit(true)
            } else {
                // splitModeChanged may represent enable/disable depending on payload.
                // Legacy behavior (no payload) assumed "enabled".
                let enabled: Bool = {
                    guard let details = event.details else { return true }
                    if details.contains("\"enabled\":false") { return false }
                    if details.contains("\"enabled\":true") { return true }
                    return true
                }()
                ensureSplit(enabled)
            }

        case .paneExitedSplit:
            ensureSplit(false)

        case .sidebarToggled, .relatedToggled, .overviewToggled:
            // UI-only intent. Current SessionState doesn't model these flags;
            // keep deterministic replay by treating as a no-op.
            break

        case .tabCreated:
            guard let tabID = event.tabID else {
                diagnostics.droppedEvents += 1
                diagnostics.warn("Dropped tabCreated with nil tabID", eventID: event.eventID)
                break
            }
            let p = paneIndex(for: event.paneID)
            ensureSplit(p == 1)

            let url = event.url.flatMap(URL.init(string:)) ?? urlByTabID[tabID] ?? DefaultURLs.aboutBlank
            urlByTabID[tabID] = urlByTabID[tabID] ?? url

            if let idx = state.windows[w].panes[p].tabOrder.firstIndex(where: { $0.tabID == tabID }) {
                state.windows[w].panes[p].tabOrder[idx].url = url
            } else {
                state.windows[w].panes[p].tabOrder.append(TabState(tabID: tabID, url: url, title: nil, lifecycleState: .frozen))
            }

            if state.windows[w].panes[p].activeTabID == nil {
                state.windows[w].panes[p].activeTabID = tabID
            }
            if state.windows[w].selectedTabID == nil {
                state.windows[w].selectedTabID = tabID
            }

        case .tabClosed:
            guard let tabID = event.tabID else {
                diagnostics.droppedEvents += 1
                diagnostics.warn("Dropped tabClosed with nil tabID", eventID: event.eventID)
                break
            }

            if !tabExists(tabID) {
                // Deterministically drop: closing a non-existent tab is a no-op.
                diagnostics.droppedEvents += 1
                diagnostics.warn("Dropped tabClosed for missing tabID", eventID: event.eventID)
                break
            }

            for p in state.windows[w].panes.indices {
                state.windows[w].panes[p].tabOrder.removeAll { $0.tabID == tabID }
                if state.windows[w].panes[p].activeTabID == tabID {
                    state.windows[w].panes[p].activeTabID = state.windows[w].panes[p].tabOrder.first?.tabID
                }
            }

            if state.windows[w].selectedTabID == tabID {
                state.windows[w].selectedTabID = state.windows[w].panes.first?.activeTabID
            }

        case .tabMovedPane:
            guard let tabID = event.tabID else {
                diagnostics.droppedEvents += 1
                diagnostics.warn("Dropped tabMovedPane with nil tabID", eventID: event.eventID)
                break
            }

            let targetPane = paneIndex(for: event.paneID)
            ensureSplit(targetPane == 1)

            if !tabExists(tabID) {
                switch policy.errorPolicy {
                case .dropInvalidEvent:
                    diagnostics.droppedEvents += 1
                    diagnostics.warn("Dropped tabMovedPane for missing tabID", eventID: event.eventID)
                    break
                case .createPlaceholderTab:
                    createPlaceholderTab(tabID: tabID, pane: targetPane)
                }
            }

            var moved: TabState?
            for p in state.windows[w].panes.indices {
                if let found = state.windows[w].panes[p].tabOrder.first(where: { $0.tabID == tabID }) {
                    moved = found
                }
                state.windows[w].panes[p].tabOrder.removeAll { $0.tabID == tabID }
                if state.windows[w].panes[p].activeTabID == tabID {
                    state.windows[w].panes[p].activeTabID = state.windows[w].panes[p].tabOrder.first?.tabID
                }
            }

            let finalURL = urlByTabID[tabID] ?? moved?.url ?? DefaultURLs.aboutBlank
            let final = TabState(tabID: tabID, url: finalURL, title: moved?.title, lifecycleState: .frozen)

            if state.windows[w].panes[targetPane].tabOrder.contains(where: { $0.tabID == tabID }) == false {
                state.windows[w].panes[targetPane].tabOrder.append(final)
            }
            state.windows[w].panes[targetPane].activeTabID = tabID
            state.windows[w].selectedTabID = tabID

        case .navigationCommitted, .urlCommitted:
            guard let tabID = event.tabID else {
                diagnostics.droppedEvents += 1
                diagnostics.warn("Dropped urlCommitted/navigationCommitted with nil tabID", eventID: event.eventID)
                break
            }
            guard let urlString = event.url, let url = URL(string: urlString) else {
                diagnostics.droppedEvents += 1
                diagnostics.warn("Dropped urlCommitted/navigationCommitted with invalid url", eventID: event.eventID)
                break
            }

            if !tabExists(tabID) {
                switch policy.errorPolicy {
                case .dropInvalidEvent:
                    diagnostics.droppedEvents += 1
                    diagnostics.warn("Dropped urlCommitted for missing tabID", eventID: event.eventID)
                    break
                case .createPlaceholderTab:
                    let p = paneIndex(for: event.paneID)
                    createPlaceholderTab(tabID: tabID, pane: p)
                }
            }

            urlByTabID[tabID] = url
            for p in state.windows[w].panes.indices {
                if let idx = state.windows[w].panes[p].tabOrder.firstIndex(where: { $0.tabID == tabID }) {
                    state.windows[w].panes[p].tabOrder[idx].url = url
                }
            }

        case .tabSuspended, .tabDiscarded:
            guard let tabID = event.tabID else {
                diagnostics.droppedEvents += 1
                diagnostics.warn("Dropped tabSuspended/tabDiscarded with nil tabID", eventID: event.eventID)
                break
            }

            if !tabExists(tabID) {
                switch policy.errorPolicy {
                case .dropInvalidEvent:
                    diagnostics.droppedEvents += 1
                    diagnostics.warn("Dropped tabSuspended/tabDiscarded for missing tabID", eventID: event.eventID)
                    break
                case .createPlaceholderTab:
                    let p = paneIndex(for: event.paneID)
                    createPlaceholderTab(tabID: tabID, pane: p)
                }
            }

            let newLifecycle: TabState.LifecycleState = (event.type == .tabDiscarded) ? .evicted : .frozen
            for p in state.windows[w].panes.indices {
                if let idx = state.windows[w].panes[p].tabOrder.firstIndex(where: { $0.tabID == tabID }) {
                    state.windows[w].panes[p].tabOrder[idx].lifecycleState = newLifecycle
                }
            }

        case .paneSelected, .paneFocused, .paneFocusChanged, .tabSelected:
            let p = paneIndex(for: event.paneID)
            if p == 1 { ensureSplit(true) }

            guard let tabID = event.tabID else {
                // Pane selection without a specific tab: select the pane's active tab if possible.
                if let active = state.windows[w].panes[p].activeTabID {
                    state.windows[w].selectedTabID = active
                } else if let first = state.windows[w].panes[p].tabOrder.first?.tabID {
                    state.windows[w].panes[p].activeTabID = first
                    state.windows[w].selectedTabID = first
                }
                break
            }

            if !tabExists(tabID) {
                switch policy.errorPolicy {
                case .dropInvalidEvent:
                    diagnostics.droppedEvents += 1
                    diagnostics.warn("Dropped tabSelected for missing tabID", eventID: event.eventID)
                    break
                case .createPlaceholderTab:
                    createPlaceholderTab(tabID: tabID, pane: p)
                }
            }

            state.windows[w].selectedTabID = tabID
            state.windows[w].panes[p].activeTabID = tabID

        case .tabReordered:
            let p = paneIndex(for: event.paneID)
            if p == 1 { ensureSplit(true) }

            guard let payloadEnvelope = event.payload else {
                // Without structured payload we can't deterministically apply a reorder.
                break
            }
            guard case .tabReordered(let payload) = payloadEnvelope.payload else {
                break
            }
            reorderTab(inPane: p, fromIndex: payload.fromIndex, toIndex: payload.toIndex)

        case .tabPinned, .tabMuted, .renderPolicyChanged, .snapshotCreated:
            // Not currently represented in SessionState; no-op for deterministic replay.
            break

        @unknown default:
            // Forward-compatibility: ignore unknown events while keeping deterministic replay.
            diagnostics.droppedEvents += 1
            diagnostics.warn("Dropped unknown journal event type", eventID: event.eventID)
            break
        }

        normalizeSelections()
    }
}
