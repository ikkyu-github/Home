import Foundation
import SafariLikeCoreKit
public enum TabEvent: Equatable {
    case createTab(profile: String, initialURL: URL?)
    case closeTab(tabID: UUID)
    case selectTab(tabID: UUID)
    case navigate(tabID: UUID, url: URL)
    case didStartLoading(tabID: UUID)
    case didFinishLoading(tabID: UUID)
    case didFailNavigation(tabID: UUID, errorCode: Int?, errorDomain: String, errorDescription: String?)
    case updateProgress(tabID: UUID, value: Double)
    case suspend(tabID: UUID)
    case resume(tabID: UUID)
    case discard(tabID: UUID)
    case restore(tabID: UUID)
    case restoreActiveTab(tabID: UUID)
    case restoreDeferredTab(tabID: UUID)
    case snapshotReady(tabID: UUID)
    case becameInactive(tabID: UUID)
    case becameActive(tabID: UUID)
}
