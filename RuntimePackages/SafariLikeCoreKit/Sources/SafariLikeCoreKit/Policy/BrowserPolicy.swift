import Foundation

/// Source of truth for browser-wide policies.
///
/// - Important: This file must remain UI-framework free (no SwiftUI/UIKit).
/// - Design: All values are `static` and immutable.
public enum BrowserPolicy {

    /// Maximum number of concurrently alive `WKWebView` instances that a single window/session
    /// should keep active at once (e.g. split panes). When at capacity, implementations must
    /// reuse or replace an existing view rather than creating an additional one.
    public static let maxConcurrentViews: Int = 2

    // MARK: - WebView Lifecycle

    /// Defaults used by CoreKit-owned tab/webview lifecycle.
    public enum WebViewLifecycle {
        /// Upper bound for concurrent alive `WKWebView` instances in memory.
        ///
        /// Note: Concrete value is intentionally conservative; UI/config layers may
        /// choose a stricter cap but should not exceed this without strong justification.
        public static let hardMaxAliveWebViews: Int = 12

        /// Minimum recommended cap for memory-constrained devices.
        public static let minimumRecommendedMaxAliveWebViews: Int = 2
    }

    // MARK: - Tab Registry

    /// Policy values used by `TabRegistry` for managing `TabWebStore` lifetimes.
    public enum TabRegistry {
        /// Lower bound for any max-alive limit.
        public static let minimumAliveWebViews: Int = 1

        /// Default max-alive limit for regular browsing.
        public static let regularMaxAliveWebViews: Int = 6

        /// Default max-alive limit for private browsing.
        public static let privateMaxAliveWebViews: Int = 2

        /// Returns the max number of alive web views allowed for a given browsing profile.
        public static func maxAliveWebViews(for profile: BrowsingProfile) -> Int {
            let requested: Int
            switch profile {
            case .regular:
                requested = regularMaxAliveWebViews
            case .private:
                requested = privateMaxAliveWebViews
            }

            return min(
                WebViewLifecycle.hardMaxAliveWebViews,
                max(minimumAliveWebViews, requested)
            )
        }
    }

    // MARK: - Navigation

    public enum Navigation {
        /// Default timeout for user-initiated navigations.
        public static let defaultNavigationTimeout: TimeInterval = 60

        /// Default timeout for background/automatic navigations.
        public static let backgroundNavigationTimeout: TimeInterval = 30

        /// Prevent pathological URL strings from allocating huge intermediate buffers.
        public static let maxURLStringLength: Int = 8_192
    }

    // MARK: - Content

    public enum Content {
        /// Whether JavaScript should be enabled by default for new web views.
        ///
        /// Actual enabling/disabling should be applied by the CoreKit webview factory.
        public static let javaScriptEnabledByDefault: Bool = true

        /// Whether back/forward swipe gestures should be enabled when hosted.
        public static let backForwardNavigationGesturesEnabledByDefault: Bool = true
    }

    // MARK: - Website Data Store

    public enum WebsiteDataStore {
        /// Default persistence choice for regular browsing.
        public static let regularUsesPersistentStore: Bool = true

        /// Private browsing always uses non-persistent storage.
        public static let privateAlwaysNonPersistent: Bool = true
    }
}
