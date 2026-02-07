import Foundation
import BrowserCore

public enum PaneID: String, Sendable, Codable, CaseIterable {
    case primary
    case secondary
}

public enum WebContextRoute: Sendable, Equatable {
    case paneDefault
    case panePrivate
    case isolated(siteKey: String, mode: WebPrivacyMode)
}

@MainActor
public final class WebContextRouter {
    private let store: SiteHeuristicsStore

    public init(store: SiteHeuristicsStore) {
        self.store = store
    }

    public func routeContext(for navigation: NavigationContext, paneID: PaneID, privacyMode: WebPrivacyMode) async -> WebContextRoute {
        let siteKey = SiteKeying.siteKey(for: navigation.url)
        let record = await store.record(for: siteKey)
        let heuristics = SiteHeuristics(siteKey: siteKey, record: record)

        if privacyMode == .private {
            if heuristics.isCrashy || heuristics.isHeavy {
                return .isolated(siteKey: siteKey, mode: .private)
            }
            return .panePrivate
        }

        if heuristics.isCrashy || heuristics.isHeavy {
            return .isolated(siteKey: siteKey, mode: .regular)
        }

        return .paneDefault
    }
}
