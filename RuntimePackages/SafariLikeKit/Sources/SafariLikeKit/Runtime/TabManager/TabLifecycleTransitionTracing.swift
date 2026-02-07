import Foundation
import SafariLikeCoreKit
@MainActor
final class TabLifecycleTransitionTracing {
    private struct Transition {
        let traceID: UUID
        let from: TabLifecycleState
        let to: TabLifecycleState
        var webViewReady: Bool
        var webViewDetached: Bool
        var snapshotApplied: Bool
        var jsInteractive: Bool
        let requiresWebViewReady: Bool
        let requiresWebViewDetached: Bool
        let requiresSnapshotApplied: Bool
        let requiresJSInteractive: Bool
        func isComplete() -> Bool {
            if requiresWebViewReady && webViewReady == false { return false }
            if requiresWebViewDetached && webViewDetached == false { return false }
            if requiresSnapshotApplied && snapshotApplied == false { return false }
            if requiresJSInteractive && jsInteractive == false { return false }
            return true
        }
    }
    private var transitionsByTabID: [UUID: Transition] = [:]
    func beginIfNeeded(
        tabID: UUID,
        from: TabLifecycleState,
        to: TabLifecycleState,
        snapshotAlreadyApplied: Bool
    ) {
        guard shouldTrace(from: from, to: to) else { return }
        // Avoid leaking a prior transition trace for the same tab.
        if let existing = transitionsByTabID[tabID] {
            PerformanceTracer.shared.endTrace(existing.traceID)
            transitionsByTabID[tabID] = nil
        }
        let requirements = requirementsForTransition(from: from, to: to)
        let traceID = PerformanceTracer.shared.startTrace(
            .tabLifecycleTransition,
            metadata: [
                "tabID": tabID.uuidString,
                "from": from.rawValue,
                "to": to.rawValue
            ]
        )
        var transition = Transition(
            traceID: traceID,
            from: from,
            to: to,
            webViewReady: false,
            webViewDetached: false,
            snapshotApplied: snapshotAlreadyApplied,
            jsInteractive: false,
            requiresWebViewReady: requirements.requiresWebViewReady,
            requiresWebViewDetached: requirements.requiresWebViewDetached,
            requiresSnapshotApplied: requirements.requiresSnapshotApplied,
            requiresJSInteractive: requirements.requiresJSInteractive
        )
        // If some requirements are not applicable, treat them as already satisfied.
        if transition.requiresWebViewReady == false { transition.webViewReady = true }
        if transition.requiresWebViewDetached == false { transition.webViewDetached = true }
        if transition.requiresSnapshotApplied == false { transition.snapshotApplied = true }
        if transition.requiresJSInteractive == false { transition.jsInteractive = true }
        transitionsByTabID[tabID] = transition
        maybeEnd(tabID: tabID)
    }
    func markSnapshotApplied(tabID: UUID) {
        guard var t = transitionsByTabID[tabID] else { return }
        t.snapshotApplied = true
        transitionsByTabID[tabID] = t
        maybeEnd(tabID: tabID)
    }
    func markWebViewReady(tabID: UUID) {
        guard var t = transitionsByTabID[tabID] else { return }
        t.webViewReady = true
        transitionsByTabID[tabID] = t
        maybeEnd(tabID: tabID)
    }
    func markWebViewDetached(tabID: UUID) {
        guard var t = transitionsByTabID[tabID] else { return }
        t.webViewDetached = true
        transitionsByTabID[tabID] = t
        maybeEnd(tabID: tabID)
    }
    func markJSInteractive(tabID: UUID) {
        guard var t = transitionsByTabID[tabID] else { return }
        t.jsInteractive = true
        transitionsByTabID[tabID] = t
        maybeEnd(tabID: tabID)
    }
    private func maybeEnd(tabID: UUID) {
        guard let t = transitionsByTabID[tabID] else { return }
        guard t.isComplete() else { return }
        PerformanceTracer.shared.endTrace(t.traceID)
        transitionsByTabID[tabID] = nil
    }
    private func shouldTrace(from: TabLifecycleState, to: TabLifecycleState) -> Bool {
        switch (from, to) {
        case (.active, .suspended):
            return true
        case (.suspended, .active):
            return true
        case (.discarded, .active):
            return true
        default:
            return false
        }
    }
    private func requirementsForTransition(from: TabLifecycleState, to: TabLifecycleState) -> (
        requiresWebViewReady: Bool,
        requiresWebViewDetached: Bool,
        requiresSnapshotApplied: Bool,
        requiresJSInteractive: Bool
    ) {
        switch (from, to) {
        case (.active, .suspended):
            // Freeze completion = snapshot captured + web view detached.
            return (requiresWebViewReady: false, requiresWebViewDetached: true, requiresSnapshotApplied: true, requiresJSInteractive: false)
        case (.suspended, .active), (.discarded, .active):
            // "Usable" definition: WebView ready + snapshot applied + JS interactive.
            return (requiresWebViewReady: true, requiresWebViewDetached: false, requiresSnapshotApplied: true, requiresJSInteractive: true)
        default:
            return (requiresWebViewReady: false, requiresWebViewDetached: false, requiresSnapshotApplied: false, requiresJSInteractive: false)
        }
    }
}
