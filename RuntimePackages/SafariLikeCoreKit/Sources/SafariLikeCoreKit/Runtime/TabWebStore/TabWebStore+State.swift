import Foundation

extension TabWebStore {
    // MARK: - State update helpers
    internal func updatePageTitle(_ value: String?) {
        pageTitle = value ?? ""
        let title = pageTitle.isEmpty ? nil : pageTitle
        updateRestoreState(currentURL: restoreState?.currentURL ?? currentURL, lastKnownTitle: title)
        notifyStateChanged()
    }

    internal func updateCurrentURL(_ value: URL?) {
        currentURL = value
        updateRestoreState(currentURL: value, lastKnownTitle: restoreState?.lastKnownTitle ?? (pageTitle.isEmpty ? nil : pageTitle))
        notifyStateChanged()
    }

    internal func updateCanGoBack(_ value: Bool) {
        canGoBack = value
        notifyStateChanged()
    }

    internal func updateCanGoForward(_ value: Bool) {
        canGoForward = value
        notifyStateChanged()
    }

    internal func updateEstimatedProgress(_ value: Double) {
        estimatedProgress = value
        notifyStateChanged()
    }

    internal func updateIsLoading(_ value: Bool) {
        isLoading = value
        notifyStateChanged()
    }

    internal func setLoading(_ value: Bool) { isLoading = value }
    internal func setProgress(_ value: Double) { estimatedProgress = value }
    internal func _setIsLoadingFlag(_ value: Bool) { setLoading(value) }
}

// MARK: - State observers
extension TabWebStore {
    /// Threading: Call on the main actor. Handler is executed
    /// on the main actor as well.
    @MainActor
    public func observeState(_ handler: @escaping @MainActor (TabWebStoreState) -> Void) -> UUID {
        let id = UUID()
        stateObservers[id] = handler
        handler(snapshotState)
        return id
    }

    /// Threading: Call on the main actor.
    @MainActor
    public func removeStateObserver(_ id: UUID) {
        stateObservers.removeValue(forKey: id)
    }

    @MainActor
    private func notifyStateChanged() {
        let state = snapshotState
        for (_, handler) in stateObservers {
            handler(state)
        }
    }
}
