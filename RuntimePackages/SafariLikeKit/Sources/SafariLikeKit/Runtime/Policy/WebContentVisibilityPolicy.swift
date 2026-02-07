import Foundation
import SafariLikeCoreKit

/// Pure UI policy for whether the web surface should be preferred over
/// Start Page / Empty layers.
///
/// Safari-like rule: if a live WebView handle exists, it wins.
public enum WebContentVisibilityPolicy {

    public struct Snapshot: Sendable, Equatable {
        public let hasLiveWebViewHandle: Bool

        public init(hasLiveWebViewHandle: Bool) {
            self.hasLiveWebViewHandle = hasLiveWebViewHandle
        }
    }

    public enum Decision: Sendable, Equatable {
        case showWebContent
        case showNonWebContent

        public var shouldPreferWebContent: Bool {
            switch self {
            case .showWebContent: return true
            case .showNonWebContent: return false
            }
        }
    }

    public static func decide(_ snapshot: Snapshot) -> Decision {
        snapshot.hasLiveWebViewHandle ? .showWebContent : .showNonWebContent
    }
}
