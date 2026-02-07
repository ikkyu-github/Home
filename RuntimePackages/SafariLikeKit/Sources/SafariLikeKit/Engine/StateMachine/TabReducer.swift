import Foundation
import SafariLikeCoreKit
public struct TabReducer {
    public static func reduce(state: TabState, event: TabEvent) -> TabState {
        var newState = state
        switch event {
        case let .createTab(_, initialURL):
            newState.lifecycle = .cold
            newState.url = initialURL
            newState.lastActiveAt = Date()
        case .selectTab:
            newState.lifecycle = .active
            newState.lastActiveAt = Date()
        case .navigate(_, let url):
            newState.url = url
            newState.lifecycle = .active
        case .didStartLoading:
            newState.lifecycle = .active
        case .didFinishLoading:
            newState.lifecycle = .active
        case .didFailNavigation:
            newState.lifecycle = .active
        case .updateProgress:
            break // progress is not part of TabState, handled elsewhere
        case .suspend:
            newState.lifecycle = .suspended
            newState.runtimeAttachment = .detached
        case .resume(_):
            newState.lifecycle = .active
            newState.runtimeAttachment = .attached
        case .discard:
            newState.lifecycle = .discarded
        case .restore:
            newState.lifecycle = .warming
        case .closeTab:
            newState.lifecycle = .closed
        case .restoreActiveTab:
            newState.lifecycle = .active
            newState.runtimeAttachment = .attached
        case .restoreDeferredTab:
            newState.lifecycle = .suspended
            newState.runtimeAttachment = .detached
        case .snapshotReady:
            newState.hasSnapshot = true
            newState.lastSnapshotAt = Date()
            newState.lifecycle = .suspended
            newState.runtimeAttachment = .detached
        case .becameInactive:
            newState.lifecycle = .suspended
        case .becameActive:
            newState.lifecycle = .active
        }
        return newState
    }
}
