import Foundation

/// Adapter for driving WebKit-backed navigation without exposing UI types.
///
/// This protocol is intentionally UI-agnostic (no WKWebView/UIView/SwiftUI references)
/// so higher layers can depend on it without pulling in platform UI.
@MainActor
public protocol WebNavigator: AnyObject {
    func goBack()
    func goForward()
    func reload()
    func stopLoading()

    /// Load a URL string (smart handling: URL vs search) using the
    /// engine's configured behavior.
    func load(_ urlString: String, force: Bool)

    /// Load a concrete URL directly.
    func load(_ url: URL, force: Bool)

    /// Load a prepared URLRequest directly.
    func load(_ request: URLRequest, force: Bool)

    /// Hint that the next load should bypass any smart split behavior.
    func setBypassSmartSplitOnce()
}
