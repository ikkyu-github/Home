import Foundation
import WebKit
import Combine

public enum WebPrivacyMode: String, Codable, Sendable {
    case regular
    case `private`
}

@MainActor
public enum WebRenderState: Sendable, Equatable {
    case active
    case suspended
    case snapshot
}

@MainActor
public final class WebContext: ObservableObject {
    public let id: UUID

    public let privacyMode: WebPrivacyMode
    public let processPool: WKProcessPool
    public let websiteDataStore: WKWebsiteDataStore
    public let contentController: WKUserContentController
    public let configuration: WKWebViewConfiguration
    public private(set) var webView: WKWebView?

    @Published public var renderState: WebRenderState = .suspended

    private let configurationCustomizer: (@MainActor (WKWebViewConfiguration) -> Void)?

    /// Designated initializer: a WebContext owns its configuration and privacy separation.
    ///
    /// WKWebView construction is intentionally delegated to `WebViewPool` to enforce
    /// budgeting and centralize ownership tracking.
    ///
    /// - Important: `configuration.processPool` will be overwritten with this context's pool
    ///   to prevent accidental cross-pane sharing.
    public init(
        configuration: WKWebViewConfiguration,
        privacyMode: WebPrivacyMode,
        configurationCustomizer: (@MainActor (WKWebViewConfiguration) -> Void)? = nil
    ) {
        self.id = UUID()
        self.privacyMode = privacyMode
        self.configurationCustomizer = configurationCustomizer

        self.processPool = WKProcessPool()
        self.contentController = configuration.userContentController
        self.configuration = configuration

        switch privacyMode {
        case .regular:
            self.websiteDataStore = .default()
        case .private:
            self.websiteDataStore = .nonPersistent()
        }

        // Apply privacy separation + enforce per-context WebProcess pool.
        WebConfigurationProvider.shared.applyPrivacyMode(privacyMode, to: self.configuration)
        self.configuration.websiteDataStore = websiteDataStore
        self.configuration.userContentController = contentController
        self.configuration.processPool = processPool
        configurationCustomizer?(self.configuration)

        // Do not create WKWebView here. It will be created lazily by WebViewPool.
        self.webView = nil
    }

    /// Convenience initializer used by runtime layers.
    public convenience init(
        privacyMode: WebPrivacyMode,
        configurationCustomizer: (@MainActor (WKWebViewConfiguration) -> Void)? = nil
    ) {
        let config = WKWebViewConfiguration()
        // Fresh controller per context to prevent script/message cross-talk.
        config.userContentController = WKUserContentController()
        self.init(
            configuration: config,
            privacyMode: privacyMode,
            configurationCustomizer: configurationCustomizer
        )
    }

    /// Compatibility API: older layers asked contexts to vend configurations.
    /// With the new architecture, the context owns a single configuration/webView.
    public func makeConfiguration() -> WKWebViewConfiguration {
        configuration
    }

    /// Lazily create (or return) the WKWebView for this context.
    ///
    /// - Important: The caller must ensure the web view is created via `WebViewPool`.
    @MainActor
    public func ensureWebViewCreated(_ factory: () -> WKWebView) -> WKWebView {
        if let webView {
            return webView
        }
        let created = factory()
        self.webView = created
        return created
    }

    /// Drop the attached WKWebView so it can be recreated by the pool.
    @MainActor
    public func discardAttachedWebViewForReparenting() {
        self.webView = nil
    }

    @MainActor
    public func ensureInitialLoad() {
        guard let webView = self.webView else { return }
        guard webView.url == nil else { return }

        let url = URL(string: "https://www.google.com")!
        let request = URLRequest(url: url)
        webView.load(request)
    }
}
