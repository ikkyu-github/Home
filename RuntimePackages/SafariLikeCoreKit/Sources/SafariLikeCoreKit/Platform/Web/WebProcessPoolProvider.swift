
import Foundation
import WebKit

/// Centralized decorator for `WKWebViewConfiguration`.
///
/// iOS 15 deprecates explicit process pool management in WebKit. This type applies
/// privacy-related configuration without referencing process pool APIs.
@MainActor
public final class WebConfigurationProvider {
    /// SAFE SINGLETON:
    /// - Process-wide WebKit configuration decorator/telemetry.
    /// - Must not store per-window/scene/tab mutable state.
    public static let shared = WebConfigurationProvider()

    private var registeredWebViewIdentifiers: Set<ObjectIdentifier> = []

    private init() {}

    /// Single source of truth for constructing `WKWebViewConfiguration`.
    ///
    /// Policy (locked):
    /// - `.private` → `WKWebsiteDataStore.nonPersistent()`
    /// - `.regular` → `WKWebsiteDataStore.default()`
    /// - processPool: system default (do not set)
    @MainActor
    public func makeWebViewConfiguration(profile: BrowsingProfile) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        switch profile {
        case .regular:
            config.websiteDataStore = .default()
        case .private:
            config.websiteDataStore = .nonPersistent()
        }

        config.defaultWebpagePreferences.allowsContentJavaScript = true

        // Fresh controller per webview to prevent message/script cross-talk.
        config.userContentController = WKUserContentController()

        // Primary behavior: apply locked media defaults at configuration creation time.
        WebViewMediaPolicy.applyMediaDefaults(to: config)

        return config
    }

    /// Applies privacy mode to an existing configuration.
    ///
    /// - Important: Does not set `config.processPool` (system default).
    ///             Privacy separation is achieved primarily via `websiteDataStore`.
    public func applyPrivacyMode(_ mode: WebPrivacyMode, to config: WKWebViewConfiguration) {
        switch mode {
        case .regular:
            config.websiteDataStore = .default()
        case .private:
            config.websiteDataStore = .nonPersistent()
        }

        // If the app adopts an app-bound domains policy, set:
        // config.limitsNavigationsToAppBoundDomains = <policy value>
        // here or by a higher-layer configuration customizer.
    }

    /// Registers a webView for best-effort telemetry tracking.
    public func register(_ webView: WKWebView) {
        WebViewPool.assertWebViewAllocatedByPool(webView)
        registeredWebViewIdentifiers.insert(ObjectIdentifier(webView))
    }

    /// Unregisters a webView from telemetry tracking.
    public func unregister(_ webView: WKWebView) {
        WebViewPool.assertWebViewAllocatedByPool(webView)
        registeredWebViewIdentifiers.remove(ObjectIdentifier(webView))
    }

    /// Returns the count of registered webViews (best-effort for telemetry).
    public var registeredWebViewCount: Int {
        registeredWebViewIdentifiers.count
    }
}
