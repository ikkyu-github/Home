import BrowserCore
import Foundation
import SafariLikeCoreKit

@MainActor
final class TabCoordinator {
    private weak var manager: TabManager?
    private var bindActiveTabTask: Task<Void, Never>?

    private var boundTabID: UUID?
    private weak var boundStore: SafariLikeCoreKit.TabWebStore?
    private var activeTabObserverID: UUID?

    init(manager: TabManager) {
        self.manager = manager
    }

    // MARK: - Tab Selection

    func selectTab(_ id: UUID) {
        guard let manager else {
            assertionFailure("TabCoordinator.manager deallocated before selectTab")
            return
        }
        manager.withCurrentSessionStore { store in
            store.selectTab(id: id)
        }
        activateTab(id)
    }

    // MARK: - Tab Activation

    func activateTab(_ id: UUID) {
        guard let manager else {
            assertionFailure("TabCoordinator.manager deallocated before activateTab")
            return
        }
        guard manager.sessionStore.tabs.contains(where: { $0.id == id }) else { return }
        RuntimeMetrics.shared.increment(.tabActivated)
        manager.recordLifecycleEvent("tab.activate")
        bindActiveTab(id: id)

        manager.withCurrentSessionStore { store in
            let url = store.tabs.first(where: { $0.id == id })?.urlString ?? manager.defaultHomeURLString
            ensureTabLoadedIfNeeded(tabID: id, preferredURL: url)
        }

        syncAddressFromActive()
        emitNavState()
    }

    // MARK: - Binding

    func bindActiveTab(id: UUID) {
        guard let manager else {
            assertionFailure("TabCoordinator.manager deallocated before bindActiveTab")
            return
        }

        let tx = manager.beginBindingTransaction(reason: "bindActiveTab", targetTabID: id)
        manager.activeBindingState = .binding(id)
        RuntimeMetrics.shared.increment(.tabBound)
        manager.recordLifecycleEvent("tab.binding")

        bindActiveTabTask?.cancel()
        bindActiveTabTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard let manager = self.manager else {
                assertionFailure("TabCoordinator.manager deallocated during bind task")
                return
            }

            guard manager.isCurrentBindingTransaction(tx) else {
                manager.logBindingRace(kind: "stale.bind.start", tx: tx, tabID: id, context: "TabCoordinator.bindActiveTab")
                return
            }

            // Unbind previous store without publishing an intermediate .unbound state.
            // The manager must remain in .binding(id) throughout this async transition.
            self.unbindActiveStore(preserveManagerBindingState: true)
            self.boundTabID = id

            var protected: Set<UUID> = []
            if manager.isSplitViewEnabled {
                if let left = manager.leftTabID { protected.insert(left) }
                if let right = manager.rightTabID { protected.insert(right) }
            }

            guard let runtime = manager.runtime(for: id, role: .primary) else {
                RuntimeMetrics.shared.increment(.runtimeInvariantViolation)
                return
            }
            let store = await runtime.activate(protectedTabIDs: protected)

            if store.webViewHandle == nil {
                manager.recordWebViewWarning("POST-ACTIVATE webViewHandle is nil (tabID=\(id.uuidString)) -> will stay in attaching until WebView attaches. Check activationSuppressed/overview state.")
            }

            guard manager.isCurrentBindingTransaction(tx) else {
                manager.logBindingRace(kind: "stale.bind.afterActivate", tx: tx, tabID: id, context: "TabCoordinator.bindActiveTab")
                return
            }

            manager.setLifecycle(tabID: id, lifecycle: .active, runtimeAttachment: .attached)

            if manager.isSessionRestoreInProgress {
                let urlString = manager.sessionStore.tabs.first(where: { $0.id == id })?.urlString
                let trimmed = urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let isBlank = trimmed.isEmpty || trimmed.lowercased() == "about:blank"
                if isBlank {
                    manager.markSessionRestoreTabInteractive(tabID: id)
                    manager.maybeEndSessionRestoreTraceIfSatisfied()
                }
            }

            RuntimeMetrics.shared.increment(.webViewActivated)
            if manager.isPerformingSessionRestore == false, store.webViewHandle == nil {
                manager.recordWebViewWarning("Activated store missing webViewHandle. context=TabCoordinator.bindActiveTab")
            }

            self.boundStore = store

            store.onWebInputFocused = { [weak self] in self?.manager?.onWebInputFocused?() }
            store.onDownloadRequested = { [weak self] request, response in
                self?.manager?.downloadStore.startDownload(request: request, response: response)
            }
            store.onDownloadDecideDestination = { [weak self] (_, _, filename) in
                self?.manager?.downloadStore.makeDestinationURL(for: filename)
            }
            store.onDownloadDidFinish = { [weak self] _ in self?.manager?.downloadStore.refresh() }
            store.onDownloadDidFail = { [weak self] error in self?.manager?.downloadStore.lastErrorMessage = error.localizedDescription }
            store.onCompanionItems = { [weak self] items in self?.manager?.onCompanionItemsUpdate?(items) }

            store.onPolicyDecisionEvent = { [weak self] event in
                guard let manager = self?.manager else { return }
                manager.onJournalEvent?(event)
                NavigationPolicyOverlayModel.shared.record(journalEvent: event)
            }

            store.onNavigationCommitted = { [weak self] url in
                guard let manager = self?.manager else { return }
                guard manager.isCurrentBindingTransaction(tx) else {
                    manager.logBindingRace(kind: "stale.commit", tx: tx, tabID: id, context: "TabCoordinator.onNavigationCommitted")
                    return
                }

                let urlString = url?.absoluteString
                let previousURL = manager.sessionStore.tabs.first(where: { $0.id == id })?.urlString

                if let urlString, previousURL != urlString {
                    manager.withCurrentSessionStore { store in
                        store.updateTab(id: id, urlString: urlString)
                        store.updateTab(id: id, title: manager.pageTitle ?? "")
                    }

                    // Safari-grade: emit only after WKNavigation commit.
                    manager.onJournalEvent?(SessionJournalEvent(
                        type: .navigationCommitted,
                        windowID: manager.windowID,
                        paneID: manager.paneID(for: id),
                        tabID: id,
                        url: urlString
                    ))

                    manager.onSessionAutosaveRequested?("navigationCommit")
                    manager.onAddressShouldSync?(urlString)
                }
            }

            store.onOpenInNewTabRequested = { [weak self] request in
                self?.manager?.openInNewTabFromPolicy(request: request)
            }

            self.activeTabObserverID = store.observeState { [weak self] state in
                guard let self else { return }
                guard let manager = self.manager else {
                    assertionFailure("TabCoordinator.manager deallocated during state observation")
                    return
                }

                // Ignore late store events for a no-longer-current binding transaction.
                guard manager.isCurrentBindingTransaction(tx) else {
                    manager.logBindingRace(kind: "stale.store.observer", tx: tx, tabID: id, context: "TabCoordinator.observeState")
                    return
                }

                manager.pageTitle = state.pageTitle
                manager.currentURL = state.currentURL
                manager.canGoBack = state.canGoBack
                manager.canGoForward = state.canGoForward
                manager.estimatedProgress = state.estimatedProgress
                manager.isLoading = state.isLoading

                if let url = state.currentURL?.absoluteString {
                    let previousURL = manager.sessionStore.tabs.first(where: { $0.id == id })?.urlString
                    manager.withCurrentSessionStore { store in
                        store.updateTab(id: id, urlString: url)
                        store.updateTab(id: id, title: state.pageTitle ?? "")
                    }
                    // Do not journal here: URL KVO can change outside didCommit (e.g. history.replaceState).
                    // Journaling of navigation commits is handled by TabWebStore.onNavigationCommitted.
                    if previousURL != url {
                        manager.onAddressShouldSync?(url)
                    }
                } else if let title = state.pageTitle {
                    manager.withCurrentSessionStore { store in
                        store.updateTab(id: id, title: title)
                    }
                }

                let activeStore = manager.activeStore
                let s = activeStore?.state
                manager.onNavStateChange?(
                    s?.canGoBack ?? false,
                    s?.canGoForward ?? false,
                    s?.isLoading ?? false,
                    s?.estimatedProgress ?? 0.0
                )
            }

            manager.activeBindingState = .bound(id)
            manager.recordLifecycleEvent("tab.bound")
            manager.validateActiveWebViewState(context: "TabCoordinator.bindActiveTab.bound")
        }
    }

    func unbindActiveStore(cancelBindTask: Bool = false, preserveManagerBindingState: Bool = false) {
        if cancelBindTask {
            bindActiveTabTask?.cancel()
        }

        guard let manager else {
            assertionFailure("TabCoordinator.manager deallocated before unbindActiveStore")
            return
        }

        RuntimeMetrics.shared.increment(.tabUnbound)
        manager.recordLifecycleEvent("tab.unbinding")

        let previousID = boundTabID
        let store = boundStore

        if let id = previousID, let webView = store?.webView {
            manager.snapshotService.captureSnapshot(tabID: id, webView: webView)
        }

        if preserveManagerBindingState == false {
            if let id = previousID {
                manager.activeBindingState = .unbinding(id)
            } else {
                manager.activeBindingState = .unbound
            }
        }

        if let observerID = activeTabObserverID {
            store?.removeStateObserver(observerID)
            activeTabObserverID = nil
        }

        store?.onCompanionItems = nil
        store?.onWebInputFocused = nil
        store?.onDownloadRequested = nil
        store?.onDownloadDecideDestination = nil
        store?.onDownloadDidFinish = nil
        store?.onDownloadDidFail = nil

        boundStore = nil
        boundTabID = nil

        if preserveManagerBindingState == false {
            manager.activeBindingState = .unbound
        }
        manager.recordLifecycleEvent("tab.unbound")
    }

    // MARK: - Pane Selection

    func selectLeftPane() {
        guard let manager else {
            assertionFailure("TabCoordinator.manager deallocated before selectLeftPane")
            return
        }
        manager.activePane = .left
    }

    func selectRightPane() {
        guard let manager else {
            assertionFailure("TabCoordinator.manager deallocated before selectRightPane")
            return
        }
        manager.activePane = .right
    }

    // MARK: - Cleanup

    func cleanupForDeinit() {
        // Match the previous TabManager deinit behavior: nil callbacks on the currently
        // bound store without doing any synchronous main-actor hops.
        let store = boundStore
        Task { @MainActor in
            store?.onCompanionItems = nil
            store?.onWebInputFocused = nil
            store?.onDownloadDecideDestination = nil
            store?.onDownloadDidFinish = nil
            store?.onDownloadDidFail = nil
        }
        bindActiveTabTask?.cancel()
    }

    // MARK: - Helpers

    private func emitNavState() {
        guard let manager else {
            assertionFailure("TabCoordinator.manager deallocated before emitNavState")
            return
        }
        let store = manager.activeStore
        let s = store?.state
        manager.onNavStateChange?(
            s?.canGoBack ?? false,
            s?.canGoForward ?? false,
            s?.isLoading ?? false,
            s?.estimatedProgress ?? 0.0
        )
    }

    private func ensureTabLoadedIfNeeded(tabID: UUID, preferredURL: String?) {
        Task { @MainActor [weak manager] in
            guard let manager else { return }

            var protected: Set<UUID> = []
            if manager.isSplitViewEnabled {
                if let left = manager.leftTabID { protected.insert(left) }
                if let right = manager.rightTabID { protected.insert(right) }
            }

            guard let runtime = manager.runtime(for: tabID, role: .primary) else {
                RuntimeMetrics.shared.increment(.runtimeInvariantViolation)
                return
            }
            let store = await runtime.activate(protectedTabIDs: protected)

            if store.state.currentURL != nil { return }

            let trimmedURL = preferredURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            let url: String
            if let trimmed = trimmedURL, !trimmed.isEmpty {
                url = trimmed
            } else {
                url = manager.defaultHomeURLString
            }

            let navigation = manager.navigationService ?? NavigationService(tabManager: manager)
            navigation.loadURLString(url, in: store, force: true)
        }
    }

    private func syncAddressFromActive() {
        guard let manager else {
            assertionFailure("TabCoordinator.manager deallocated before syncAddressFromActive")
            return
        }
        if let url = manager.activeStore?.state.currentURL?.absoluteString {
            manager.onAddressShouldSync?(url)
        }
    }

    deinit {
        bindActiveTabTask?.cancel()
    }
}
