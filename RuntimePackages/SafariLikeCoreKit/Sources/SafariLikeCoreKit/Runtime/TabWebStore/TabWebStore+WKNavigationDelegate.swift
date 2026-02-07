import Foundation
import WebKit
import BrowserCore

extension TabWebStore: WKNavigationDelegate {
    /// Apply per-site preferences at navigation time.
    ///
    /// This is the preferred hook for things like JavaScript enablement because
    /// WebKit supports per-navigation webpage preferences.
    @available(iOS 13.0, *)
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
		WebViewPool.assertWebViewAllocatedByPool(webView)
		navigationController.webView(
			webView,
			decidePolicyFor: navigationAction,
			preferences: preferences,
			decisionHandler: decisionHandler
		)
    }

    /// Intercept navigation responses that should be downloaded.
    ///
    /// The app can manage the download using its own infrastructure (e.g. background
    /// URLSession) by subscribing to `onDownloadRequested`.
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
		WebViewPool.assertWebViewAllocatedByPool(webView)
		navigationController.webView(
			webView,
			decidePolicyFor: navigationResponse,
			decisionHandler: decisionHandler
		)
    }

    /// Threading: Called by WebKit on the main actor.
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		WebViewPool.assertWebViewAllocatedByPool(webView)
		navigationController.webView(webView, didStartProvisionalNavigation: navigation)
    }

    /// Threading: Called by WebKit on the main actor.
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
		WebViewPool.assertWebViewAllocatedByPool(webView)
		navigationController.webView(webView, didCommit: navigation)
    }

    /// Threading: Called by WebKit on the main actor.
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		WebViewPool.assertWebViewAllocatedByPool(webView)
		navigationController.webView(webView, didFinish: navigation)
    }

    /// Threading: Called by WebKit on the main actor.
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		WebViewPool.assertWebViewAllocatedByPool(webView)
		navigationController.webView(webView, didFail: navigation, withError: error)
    }

    /// Threading: Called by WebKit on the main actor.
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		WebViewPool.assertWebViewAllocatedByPool(webView)
		navigationController.webView(webView, didFailProvisionalNavigation: navigation, withError: error)
    }

    /// Threading: Called by WebKit on the main actor.
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
		WebViewPool.assertWebViewAllocatedByPool(webView)
		navigationController.webViewWebContentProcessDidTerminate(webView)
    }
}
