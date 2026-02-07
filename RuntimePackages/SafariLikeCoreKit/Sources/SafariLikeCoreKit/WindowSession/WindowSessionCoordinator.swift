import Foundation
import BrowserCore

/// Owns all mutations of a window session (tabs + window-level preferences) and
/// performs side-effects (navigation) behind CoreKit boundaries.
@MainActor
public final class WindowSessionCoordinator {

    public struct Runtime {
        public let sessionStore: BrowserSessionStore
        public let browserState: any BrowserStateCoordinating

        public init(sessionStore: BrowserSessionStore, browserState: any BrowserStateCoordinating) {
            self.sessionStore = sessionStore
            self.browserState = browserState
        }
    }

    public let windowSession: WindowSession

    private let regular: Runtime
    private let `private`: Runtime

    private var didTriggerLaunchLazyLoad = false

    public init(
        windowSession: WindowSession,
        regular: Runtime,
        private: Runtime
    ) {
        self.windowSession = windowSession
        self.regular = regular
        self.private = `private`
        windowSession.bind(to: currentRuntime.sessionStore)
    }

    public var browsingProfile: BrowsingProfile {
        windowSession.browsingProfile
    }

    public var sessionStore: BrowserSessionStore {
        currentRuntime.sessionStore
    }

    private var currentRuntime: Runtime {
        switch windowSession.browsingProfile {
        case .regular:
            return regular
        case .private:
            return `private`
        }
    }

    // MARK: - Window-level state

    public func setSidebarMode(_ mode: SidebarMode) {
        windowSession.sidebarMode = mode
    }

    public func setBrowsingProfile(_ profile: BrowsingProfile) {
        guard windowSession.browsingProfile != profile else { return }
        windowSession.browsingProfile = profile
        windowSession.bind(to: currentRuntime.sessionStore)

        // Best-effort: ensure there is a selection in the new profile.
        if sessionStore.selectedTabID == nil {
            _ = sessionStore.addTab()
        }
    }

    // MARK: - Tabs

    @discardableResult
    public func newTab(inGroup groupID: UUID? = nil, inBackground: Bool = false) -> UUID {
        let newID = sessionStore.addTab()
        if let groupID {
            sessionStore.addTabToGroup(tabID: newID, groupID: groupID)
        }

        if inBackground {
            // Revert selection if caller intended background creation.
            // (BrowserSessionStore always selects on addTab())
            // Best-effort: pick previous active if it exists.
            if let previous = windowSession.activeTabID {
                sessionStore.selectTab(id: previous)
            }
        }
        return newID
    }

    public func selectTab(_ id: UUID) {
        sessionStore.selectTab(id: id)
    }

    public func closeTab(_ id: UUID) async {
        sessionStore.closeTab(id: id)
        await currentRuntime.browserState.remove(tabID: id)
    }

    public func moveTab(from: Int, to: Int) {
        sessionStore.moveTab(from: from, to: to)
    }

    // MARK: - Navigation

    public func openURL(_ url: URL, force: Bool = false) async {
        guard let tabID = windowSession.activeTabID ?? sessionStore.selectedTabID else { return }

        // Commit URL to session metadata first for Safari-like UX (address bar + Start Page dismissal).
        sessionStore.updateTab(id: tabID, title: nil, urlString: url.absoluteString)

        let store: any WebStoreProviding = await currentRuntime.browserState.activatedWebStore(
            for: tabID,
            role: .primary,
            protectedTabIDs: [tabID]
        )
        store.load(url, force: force)
    }

    public func openURLString(_ urlString: String, force: Bool = false) async {
        guard let tabID = windowSession.activeTabID ?? sessionStore.selectedTabID else { return }
        sessionStore.updateTab(id: tabID, title: nil, urlString: urlString)

        let store: any WebStoreProviding = await currentRuntime.browserState.activatedWebStore(
            for: tabID,
            role: .primary,
            protectedTabIDs: [tabID]
        )
        store.load(urlString, force: force)
    }

    public func reload() {
        guard let tabID = windowSession.activeTabID ?? sessionStore.selectedTabID else { return }
        let store: (any WebStoreProviding)? = currentRuntime.browserState.existingWebStore(for: tabID)
        if let store {
            store.reload()
            return
        }
        Task { @MainActor in
            let activated: any WebStoreProviding = await currentRuntime.browserState.activatedWebStore(
                for: tabID,
                role: .primary,
                protectedTabIDs: [tabID]
            )
            activated.reload()
        }
    }

    public func goBack() {
        guard let tabID = windowSession.activeTabID ?? sessionStore.selectedTabID else { return }
        let store: (any WebStoreProviding)? = currentRuntime.browserState.existingWebStore(for: tabID)
        if let store {
            store.goBack()
            return
        }
        Task { @MainActor in
            let activated: any WebStoreProviding = await currentRuntime.browserState.activatedWebStore(
                for: tabID,
                role: .primary,
                protectedTabIDs: [tabID]
            )
            activated.goBack()
        }
    }

    public func goForward() {
        guard let tabID = windowSession.activeTabID ?? sessionStore.selectedTabID else { return }
        let store: (any WebStoreProviding)? = currentRuntime.browserState.existingWebStore(for: tabID)
        if let store {
            store.goForward()
            return
        }
        Task { @MainActor in
            let activated: any WebStoreProviding = await currentRuntime.browserState.activatedWebStore(
                for: tabID,
                role: .primary,
                protectedTabIDs: [tabID]
            )
            activated.goForward()
        }
    }

    /// Best-effort in-place recovery when the active tab's WebView attachment timed out.
    ///
    /// This is intentionally coordinator-owned so SwiftUI doesn't touch `WebViewHandle`.
    public func retryInPlace(tabID: UUID?, fallbackURLString: String?) async {
        guard let tabID else { return }

        // Force path: ensure policies/overview suppression cannot block recovery.
        currentRuntime.browserState.setActivationSuppressed(false)

        // Deterministic recreate semantics:
        // - Always drop the existing WKWebView instance.
        // - Always invalidate and remove the store, so activation creates a fresh store + context.
        currentRuntime.browserState.deactivateWebView(tabID: tabID, mode: .cold)
        await currentRuntime.browserState.remove(tabID: tabID)

        // Resolve what to load after recreation.
        let normalizedFallback: String? = {
            guard let s = fallbackURLString?.trimmingCharacters(in: .whitespacesAndNewlines), s.isEmpty == false else { return nil }
            return s
        }()

        let store: any WebStoreProviding = await currentRuntime.browserState.activatedWebStore(
            for: tabID,
            role: .primary,
            protectedTabIDs: [tabID]
        )

        // Prefer explicit fallback URL, else reload the best known current URL, else reload.
        if let normalizedFallback {
            store.load(normalizedFallback, force: true)
        } else if let url = store.state.currentURL, url.absoluteString.lowercased() != "about:blank" {
            store.load(url.absoluteString, force: true)
        } else {
            store.reload()
        }
    }

    // MARK: - Restore

    /// Best-effort Phase-A restore: rebuild tab list, groups, and selection without forcing WebView activation.
    public func restoreSession(_ state: BrowserCore.SessionState) {
        guard let window = state.windows.first else { return }

        var orderedTabIDs: [UUID] = []
        orderedTabIDs.reserveCapacity(window.panes.reduce(0) { $0 + $1.tabOrder.count })

        var tabByID: [UUID: BrowserCore.TabState] = [:]
        for pane in window.panes {
            for tab in pane.tabOrder {
                tabByID[tab.tabID] = tab
                if !orderedTabIDs.contains(tab.tabID) { orderedTabIDs.append(tab.tabID) }
            }
        }

        var groupByTabID: [UUID: UUID] = [:]
        for group in state.tabGroups {
            for id in group.tabIDs { groupByTabID[id] = group.id }
        }

        let now = Date()
        let tabs: [BrowserCore.BrowserTab] = orderedTabIDs.compactMap { id in
            guard let t = tabByID[id] else { return nil }
            return BrowserCore.BrowserTab(
                id: id,
                title: t.title ?? "New Tab",
                urlString: t.url.absoluteString,
                lifecycleState: .suspended,
                lastVisitedAt: now,
                groupID: groupByTabID[id]
            )
        }

        sessionStore.replaceAllTabsAndGroups(
            tabs,
            selectedTabID: window.selectedTabID,
            tabGroups: state.tabGroups,
            selectedTabGroupID: state.selectedTabGroupID
        )
    }

    /// Safari-like: after UI is visible, lazily load the active tab's URL.
    ///
    /// This keeps launch/restore feeling instant (snapshots-first) and avoids
    /// waking WebKit for every tab during restoration.
    public func loadActiveTabContentAfterUIReady(delayNanoseconds: UInt64 = 200_000_000) async {
        if didTriggerLaunchLazyLoad { return }
        didTriggerLaunchLazyLoad = true

        // Ensure persisted tab model has finished loading.
        await sessionStore.awaitInitialLoad()

        // Let the UI render snapshots before we touch WebKit.
        do { try await Task.sleep(nanoseconds: delayNanoseconds) } catch { return }

        guard let tabID = windowSession.activeTabID ?? sessionStore.selectedTabID else { return }
        guard let tab = sessionStore.tabs.first(where: { $0.id == tabID }) else { return }

        let preferred = Self.normalizedRestoredURLString(tab.urlString)
        guard let preferred else { return }

        // Activate + load only if the store is blank/uninitialized.
        let store: any WebStoreProviding = await currentRuntime.browserState.activatedWebStore(
            for: tabID,
            role: .primary,
            protectedTabIDs: [tabID]
        )
        if let current = store.state.currentURL?.absoluteString.lowercased(), current != "about:blank" {
            return
        }
        store.load(preferred, force: false)
    }

    private static func normalizedRestoredURLString(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if trimmed.lowercased() == "about:blank" { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url.absoluteString
        }

        // Best-effort: tolerate scheme-less persisted URLs.
        if let url = URL(string: "https://" + trimmed) {
            return url.absoluteString
        }

        return nil
    }
}
