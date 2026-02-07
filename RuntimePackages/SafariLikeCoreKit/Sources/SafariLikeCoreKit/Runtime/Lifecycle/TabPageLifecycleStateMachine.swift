import Foundation
import os
import BrowserCore

/// CoreKit-owned tab/page lifecycle state machine.
///
/// States:
/// - `suspended`: no live WKWebView; aggressively discarded (budget/memory pressure).
/// - `snapshotOnly`: UI may show a snapshot/thumbnail; CoreKit must not keep a live WebView attached.
/// - `liveAttached`: tab is allowed to have a live WebView.
///
/// This type is intentionally UI-free and side-effect free: it returns effects that
/// higher layers can execute using their single-writer activation APIs.
@MainActor
public struct TabPageLifecycleStateMachine: Sendable {
    public enum State: String, Sendable, Equatable {
        case suspended
        case snapshotOnly
        case liveAttached
    }

    public struct VisibilitySnapshot: Sendable, Equatable {
        public var isSplitEnabled: Bool
        public var isTabOverviewVisible: Bool
        public var activePane: BrowserCore.RenderBudgetPolicy.ActivePane
        public var activeTabID: UUID?
        public var leftTabID: UUID?
        public var rightTabID: UUID?
        public var bindingTabID: UUID?

        public init(
            isSplitEnabled: Bool,
            isTabOverviewVisible: Bool,
            activePane: BrowserCore.RenderBudgetPolicy.ActivePane,
            activeTabID: UUID?,
            leftTabID: UUID?,
            rightTabID: UUID?,
            bindingTabID: UUID?
        ) {
            self.isSplitEnabled = isSplitEnabled
            self.isTabOverviewVisible = isTabOverviewVisible
            self.activePane = activePane
            self.activeTabID = activeTabID
            self.leftTabID = leftTabID
            self.rightTabID = rightTabID
            self.bindingTabID = bindingTabID
        }
    }

    public enum Event: Sendable, Equatable {
        case reconcileVisibility(snapshot: VisibilitySnapshot, candidates: [UUID], reason: String)
        case rootViewAppeared(activeTabID: UUID?)
        case tabActivated(tabID: UUID)
        case tabSuspended(tabID: UUID)
        case webViewAttached(tabID: UUID)
        case webViewDetached(tabID: UUID)
    }

    public enum Effect: Sendable, Equatable {
        case activate(tabID: UUID, protectedTabIDs: Set<UUID>, reason: String)
        case deactivateToSnapshotOnly(tabID: UUID, reason: String)
        case suspend(tabID: UUID, reason: String)
    }

    private static let logger = Logger(subsystem: "SafariLikeCoreKit", category: "TabPageLifecycle")

    private var stateByTabID: [UUID: State] = [:]
    private var activeTabID: UUID? = nil

    public init() {}

    public func state(tabID: UUID) -> State {
        stateByTabID[tabID] ?? .snapshotOnly
    }

    @discardableResult
    public mutating func handle(
        event: Event,
        sceneID: String
    ) -> [Effect] {
        switch event {
        case .reconcileVisibility(let snapshot, let candidates, let reason):
            return reconcileVisibility(snapshot: snapshot, candidates: candidates, sceneID: sceneID, reason: reason)

        case .rootViewAppeared(let active):
            activeTabID = active
            return []

        case .tabActivated(let tabID):
            activeTabID = tabID
            return []

        case .tabSuspended(let tabID):
            if activeTabID == tabID { activeTabID = nil }
            return transition(tabID: tabID, to: .suspended, sceneID: sceneID, reason: "tabSuspended")

        case .webViewAttached(let tabID):
            // Treat as a runtime signal; keep state as live if already allowed.
            // If UI attaches unexpectedly, do not escalate budgets here.
            let current = state(tabID: tabID)
            if current == .liveAttached { return [] }
            // Downgrade back to snapshotOnly; higher layers should reconcile.
            return transition(tabID: tabID, to: .snapshotOnly, sceneID: sceneID, reason: "webViewAttached.unexpected")

        case .webViewDetached(let tabID):
            // UI detached; ensure we are at most snapshotOnly.
            if activeTabID == tabID {
                // Active tab detaching is usually transient (e.g. reparenting). Keep desired live.
                return []
            }
            return transition(tabID: tabID, to: .snapshotOnly, sceneID: sceneID, reason: "webViewDetached")
        }
    }

    private mutating func reconcileVisibility(
        snapshot: VisibilitySnapshot,
        candidates: [UUID],
        sceneID: String,
        reason: String
    ) -> [Effect] {
        let keepSet: Set<UUID> = {
            if snapshot.isTabOverviewVisible { return [] }
            let input = BrowserCore.RenderBudgetPolicy.Input(
                isSplitEnabled: snapshot.isSplitEnabled,
                isTabOverviewVisible: snapshot.isTabOverviewVisible,
                activePane: snapshot.activePane,
                activeTabID: snapshot.activeTabID,
                leftTabID: snapshot.leftTabID,
                rightTabID: snapshot.rightTabID,
                bindingTabID: snapshot.bindingTabID
            )
            let decision = BrowserCore.RenderBudgetPolicy.decide(input: input, candidates: candidates)
            return Set(decision.keepRendered)
        }()

        var effects: [Effect] = []
        for tabID in candidates {
            let current = state(tabID: tabID)
            // Preserve explicit suspension unless the tab must be live.
            if current == .suspended, keepSet.contains(tabID) == false {
                continue
            }
            let desired: State = keepSet.contains(tabID) ? .liveAttached : .snapshotOnly
            effects.append(contentsOf: transition(
                tabID: tabID,
                to: desired,
                sceneID: sceneID,
                reason: "reconcile.\(reason)",
                protectedTabIDs: keepSet
            ))
        }
        // Keep a best-effort activeTabID hint for future single-tab events.
        if let active = snapshot.activeTabID {
            activeTabID = active
        }
        return effects
    }

    private mutating func transition(
        tabID: UUID,
        to newState: State,
        sceneID: String,
        reason: String,
        protectedTabIDs: Set<UUID>? = nil
    ) -> [Effect] {
        let oldState = state(tabID: tabID)
        if oldState == newState { return [] }
        stateByTabID[tabID] = newState

        #if DEBUG
        let msg = "[TabPageLifecycle] scene=\(sceneID) tab=\(tabID.uuidString) \(oldState.rawValue)->\(newState.rawValue) reason=\(reason)"
        Self.logger.debug("\(msg, privacy: .public)")
        Diagnostics.logDebug(msg, subsystem: .runtime, category: "TabPageLifecycle")
        #endif

        switch newState {
        case .liveAttached:
            return [.activate(tabID: tabID, protectedTabIDs: protectedTabIDs ?? [tabID], reason: reason)]
        case .snapshotOnly:
            return [.deactivateToSnapshotOnly(tabID: tabID, reason: reason)]
        case .suspended:
            return [.suspend(tabID: tabID, reason: reason)]
        }
    }
}
