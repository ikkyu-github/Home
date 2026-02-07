import Foundation
import CoreGraphics
import SafariLikeCoreKit
import SafariLikeContracts
/// Configuration object for SafariLikeKit browser behavior.
///
/// `SafariLikeConfiguration` is one of the **three public API entrypoints** for SafariLikeKit.
/// It controls core browser policies (home URL, tab limits, split view widths, search engine) that
/// are fixed at session creation time and should not be changed frequently.
///
/// ## Contract
/// - Create a single instance per App (use `SafariLikeConfiguration.default` for most cases)
/// - Pass to ``SafariLikeFactory.makeSceneSession(sceneID:configuration:)`` when creating sessions
/// - Treat as immutable after session creation; changes don't affect existing sessions
///
/// ## Typical Usage
/// ```swift
/// let config = SafariLikeConfiguration(
///     defaultHomeURLString: "https://www.example.com",
///     maxAliveWebViews: 3,
///     minSplitActivationWidth: 800
/// )
/// let session = SafariLikeFactory.makeSceneSession(
///     sceneID: "main",
///     configuration: config
/// )
/// ```
///
/// ## Properties
/// - `defaultHomeURLString` - URL loaded when user taps home; used in new tabs
/// - `maxAliveWebViews` - Maximum number of WebKit instances kept in memory
/// - `minSplitActivationWidth` - Width threshold for enabling two-column layout on iPad
/// - `companionWidthFraction` - Width ratio of companion column (0.0...0.5)
/// - `sidebarWidth` - Width of left sidebar (bookmarks, history, etc.)
/// - `usePersistentWebsiteDataStore` - Whether to persist cookies/cache to disk
/// - `contentBlockerEnabled` - Enable/disable content blocking
/// - `searchEngineURL` - Search provider URL template
public struct SafariLikeConfiguration: Sendable {
    public var defaultHomeURLString: String
    public var usePersistentWebsiteDataStore: Bool
    public var maxAliveWebViews: Int
    /// Optional Safari-grade budgets (overrides) applied per scene.
    ///
    /// Backward-compatibility:
    /// - If overrides are nil, `maxAliveWebViews` remains the effective cap (legacy behavior).
    public var sceneBudgets: SafariLikeSceneBudgets
    public var minSplitActivationWidth: CGFloat
    public var companionWidthFraction: CGFloat
    public var sidebarWidth: CGFloat
    public var contentBlockerEnabled: Bool
    public var searchEngineURL: String
    public static let `default` = SafariLikeConfiguration()
    public init(
        defaultHomeURLString: String = SafariLikeContracts.DefaultURLs.googleHomepage.absoluteString,
        usePersistentWebsiteDataStore: Bool = true,
        maxAliveWebViews: Int = 2,
        sceneBudgets: SafariLikeSceneBudgets = SafariLikeSceneBudgets(),
        minSplitActivationWidth: CGFloat = 700,
        companionWidthFraction: CGFloat = 0.30,
        sidebarWidth: CGFloat = 320,
        contentBlockerEnabled: Bool = true,
        searchEngineURL: String = SafariLikeContracts.DefaultURLs.SearchEngine.googleQuery.absoluteString
    ) {
        self.defaultHomeURLString = defaultHomeURLString
        self.usePersistentWebsiteDataStore = usePersistentWebsiteDataStore
        self.maxAliveWebViews = max(1, maxAliveWebViews)
        self.sceneBudgets = sceneBudgets
        self.minSplitActivationWidth = max(320, minSplitActivationWidth)
        self.companionWidthFraction = min(max(0.0, companionWidthFraction), 0.50)
        self.sidebarWidth = max(240, sidebarWidth)
        self.contentBlockerEnabled = contentBlockerEnabled
        self.searchEngineURL = searchEngineURL
    }
    /// Returns the effective maxAliveWebViews.
    ///
    /// Contract:
    /// - Must not branch behavior by device idiom (iPhone/iPad).
    /// - CoreKit owns WebView lifecycle policy via `BrowserPolicy`; this helper is retained
    ///   for backward compatibility only.
    public func resolvedMaxAliveWebViews() -> Int {
        return maxAliveWebViews
    }

    /// Returns the effective maxAliveWebViews override for a specific profile.
    ///
    /// Contract: If no per-profile override is provided, falls back to the legacy
    /// `maxAliveWebViews` value for compatibility.
    public func resolvedMaxAliveWebViews(for profile: BrowsingProfile) -> Int {
        switch profile {
        case .regular:
            return max(1, sceneBudgets.maxAliveWebViewsRegularOverride ?? maxAliveWebViews)
        case .private:
            return max(1, sceneBudgets.maxAliveWebViewsPrivateOverride ?? maxAliveWebViews)

        @unknown default:
            return max(1, maxAliveWebViews)
        }
    }

    /// Returns an optional stricter cap for concurrent active WebViews.
    ///
    /// If nil, CoreKit policy is used.
    public func resolvedMaxConcurrentActiveWebViewsOverride() -> Int? {
        guard let v = sceneBudgets.maxConcurrentActiveWebViewsOverride else { return nil }
        return max(1, v)
    }
}
