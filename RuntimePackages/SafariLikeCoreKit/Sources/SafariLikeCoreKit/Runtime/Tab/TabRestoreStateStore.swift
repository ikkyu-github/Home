import Foundation

@MainActor
public final class TabRestoreStateStore: TabRestoreStateStoring {
    public private(set) var restoreState: TabRestoreState?

    public init(initial: TabRestoreState? = nil) {
        self.restoreState = initial
    }

    public func updateRestoreState(currentURL: URL?, lastKnownTitle: String?) {
        // Keep the store nil when there's no signal worth persisting.
        if currentURL == nil, lastKnownTitle == nil {
            restoreState = nil
            return
        }
        restoreState = TabRestoreState(currentURL: currentURL, lastKnownTitle: lastKnownTitle)
    }
}
