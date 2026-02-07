import Foundation
import WebKit
import os

@MainActor
public final class WebViewHandle {
    private static let logger = Logger(subsystem: "SafariLikeCoreKit", category: "WebViewHandle")
    /// Threading: All APIs on this handle must
    /// be called from the main actor.
    public weak var webView: WKWebView?
    private var strongReference: WKWebView?

    /// When backed by a pool lease, this records the current lease ID.
    ///
    /// Useful for debugging and for higher layers to avoid returning/using stale leases.
    public private(set) var leaseID: UUID?

    /// Last-known URL for this handle.
    ///
    /// Rationale: `WKWebView.url` can transiently be nil (or lag behind) even after
    /// navigation signals have fired. We track the most recent requested/committed
    /// URL so higher layers never have to treat `nil` as authoritative.
    public private(set) var lastKnownURL: URL?

    /// Threading: Call on the main actor.
    public init(webView: WKWebView, retain: Bool = true) {
        WebViewPool.assertWebViewAllocatedByPool(webView)
        self.webView = webView
        self.strongReference = retain ? webView : nil
        self.lastKnownURL = webView.url
        self.leaseID = nil
    }

    /// Bind this handle to a pool lease.
    ///
    /// Call this when a tab borrows a `WKWebView` from `WebViewPool`.
    public func bind(to lease: WebViewPool.WebViewLease, retain: Bool = true) {
        WebViewPool.assertWebViewAllocatedByPool(lease.webView)
        self.webView = lease.webView
        self.strongReference = retain ? lease.webView : nil
        self.leaseID = lease.leaseID
        self.lastKnownURL = lease.webView.url
    }

    /// Drop references to the underlying web view.
    ///
    /// Call this when returning a lease to the pool so the tab no longer retains the `WKWebView`.
    public func unbind() {
        self.strongReference = nil
        self.webView = nil
        self.leaseID = nil
    }

    /// Threading: Read on the main actor.
    public var isAlive: Bool {
        webView != nil
    }

    /// Threading: Call on the main actor.
    public func load(url: URL) {
        lastKnownURL = url
        guard let webView else {
            #if DEBUG
            Self.logger.debug("WebViewHandle.load ignored: webView is nil url=\(url.absoluteString, privacy: .public)")
            #endif
            return
        }
        #if DEBUG
        Self.logger.debug("WebViewHandle.load(url:) -> WKWebView.load url=\(url.absoluteString, privacy: .public)")
        #endif
        webView.load(URLRequest(url: url))
    }

    /// Threading: Call on the main actor.
    public func load(request: URLRequest) {
        if let url = request.url {
            lastKnownURL = url
        }
        webView?.load(request)
    }

    /// Threading: Call on the main actor.
    public func goBack() {
        webView?.goBack()
    }

    /// Threading: Call on the main actor.
    public func goForward() {
        webView?.goForward()
    }

    /// Threading: Call on the main actor.
    public func reload() {
        webView?.reload()
    }

    /// Threading: Read on the main actor.
    public var url: URL? {
        webView?.url
    }

    /// Returns the best-effort URL for UI/diagnostics.
    /// Prefer the live WebKit URL, but fall back to the last-known URL.
    public var effectiveURL: URL? {
        webView?.url ?? lastKnownURL
    }

    /// Threading: Call on the main actor.
    internal func updateLastKnownURL(_ url: URL?) {
        guard let url else { return }
        lastKnownURL = url
    }

    /// Threading: Call on the main actor.
    public func stopLoading() {
        webView?.stopLoading()
    }

    /// Threading: Read on the main actor.
    public var configuration: WKWebViewConfiguration? {
        webView?.configuration
    }

    /// Threading: Get/set on the main actor.
    public var customUserAgent: String? {
        get { webView?.customUserAgent }
        set { webView?.customUserAgent = newValue }
    }

    /// Threading: Read on the main actor.
    public var navigationDelegate: WKNavigationDelegate? {
        webView?.navigationDelegate
    }

    /// Threading: Call on the main actor.
    internal func setNavigationDelegate(_ delegate: WKNavigationDelegate?) {
        webView?.navigationDelegate = delegate
    }

    /// Threading: Read on the main actor.
    public var uiDelegate: WKUIDelegate? {
        webView?.uiDelegate
    }

    /// Threading: Call on the main actor.
    internal func setUIDelegate(_ delegate: WKUIDelegate?) {
        webView?.uiDelegate = delegate
    }

    /// Threading: Call on the main actor.
    public func withUserContentController(_ body: (WKUserContentController) -> Void) {
        guard let controller = webView?.configuration.userContentController else { return }
        body(controller)
    }

    /// Threading: Call on the main actor.
    public func evaluateJavaScript(_ js: String, completion: @escaping @Sendable (Any?, Error?) -> Void) {
        webView?.evaluateJavaScript(js, completionHandler: completion)
    }
}
