import Foundation
import SafariLikeCoreKit

/// Pure UI policy: does this tab state *require* a WKWebView?
///
/// Important: This is a UI/rendering requirement only. Runtime may still hold an
/// existing web view handle transiently (e.g. after navigation) but UI should
/// not force attachment for non-web tabs.
public enum WebViewRequirementPolicy {

    public enum Decision: Sendable, Equatable {
        case required
        case notRequired

        public var requiresWebView: Bool {
            switch self {
            case .required: return true
            case .notRequired: return false
            }
        }
    }

    public static func decide(tabState: BrowserTab.State?) -> Decision {
        guard let tabState else { return .notRequired }
        switch tabState {
        case .web:
            return .required
        case .startPage, .empty:
            return .notRequired
        @unknown default:
            return .notRequired
        }
    }
}
