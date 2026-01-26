import Foundation
import WebKit
import os
import BrowserCore

/// Threading: TabWebStore is main-actor isolated; all public
/// APIs must be called from the main actor.
///
/// Lifecycle & ownership contract:
/// - A TabWebStore instance is created by TabRegistry with its own WKWebView
///   via `TabWebStore.makeWebView(configuration:)`.
/// - TabWebStore is the single owner responsible for configuring, observing,
///   and tearing down that WKWebView. Callers must *not* install additional
///   delegates, KVO observers, or script message handlers directly on the view.
/// - `activate()` installs observers for WebView state; it is idempotent and
///   should be called once after creation.
/// - `invalidate()` is the terminal teardown entry point and will:
///     - delegate to `resetForReuseInternal(defaultHomeURLString:)` to cancel
///       internal async work and reset navigation-related state
///     - remove delegates, KVO observers, and injected scripts/handlers
///     - stop any in-flight loads
///     - clear all external callbacks and state observers
///   After `invalidate()` the store and its webView are considered unusable.
/// - For future reuse of a WKWebView with the same TabWebStore instance,
///   extensions may call `resetForReuseInternal(defaultHomeURLString:)`
///   followed by WebView reconfiguration APIs, without ever mutating
///   internal state directly.
/// - Each instance is bound to a `BrowsingProfile` (regular/private) which
///   determines the underlying `WKWebsiteDataStore` via
///   `WebViewConfigurationFactory(profile:)`. UI and ViewModel layers must
///   treat the underlying WKWebView as an implementation detail owned by
///   TabWebStore and must not install delegates or hold long-lived
///   references to it.
///
/// Threading notes:
/// - ชนิดนี้เก็บ state และอ้างอิงไปยัง `WKWebView` ภายใน และถูกผูกกับ `@MainActor`
///   ที่ระดับคลาส ดังนั้นทุกเมทอด instance จะรันบน main actor โดยอัตโนมัติ.
// Helper for printing WKWebView pointer safely
private func webViewPointerString(_ webView: WKWebView?) -> String {
    guard let webView else { return "nil" }
    return "\(Unmanaged.passUnretained(webView).toOpaque())"
}

@MainActor
public final class TabWebStore: NSObject {
    nonisolated private static let deinitLogger = Logger(subsystem: "SafariLikeKit", category: "TabWebStore")
    private let configFactory: WebViewConfigurationFactory
        #if DEBUG
        private let debugLogEnabled = true
        #else
        private let debugLogEnabled = false
        #endif
    // MARK: - App State Abstraction
    /// Closure to check if app is active, settable from UI layer. Defaults to always true.
    var isAppActiveClosure: (() -> Bool)?
    // MARK: - Types
    public enum Role {
        case primary
        case companion
        case popup
        case pictureInPicture
    }

    // MARK: - Public state
    public let tabID: UUID
    public let windowID: String
    public let paneID: String
    public let role: Role
    public let browsingProfile: BrowsingProfile

    /// Pane/tab-scoped WebKit runtime. Owns the `WKWebView` and its configuration.
    public private(set) var webContext: WebContext?

    public let uxRestoreController = UXRestoreController()
    internal var pageTitle: String = ""
    internal var currentURL: URL?
    internal var canGoBack: Bool = false
    internal var canGoForward: Bool = false
    internal var isLoading: Bool = false
    internal var estimatedProgress: Double = 0

    // MARK: - Lightweight Navigation Metrics

    /// Timestamp set on didStartProvisionalNavigation for load time estimation.
    internal var navigationStartAt: Date?

    /// Threading: Read on the main actor.
    public var state: TabWebStoreState {
        TabWebStoreState(
            pageTitle: pageTitle,
            currentURL: currentURL,
            canGoBack: canGoBack,
            canGoForward: canGoForward,
            estimatedProgress: estimatedProgress,
            isLoading: isLoading
        )
    }

    internal var stateObservers: [UUID: @MainActor (TabWebStoreState) -> Void] = [:]

    /// Minimal, synchronous cleanup for owner deinit. Do not call WebKit APIs here.
    internal func invalidateForOwnerDeinit() {
        if isInvalidated { return }
        isInvalidated = true

        stateObservers.removeAll()

        onWebViewBecameFirstResponder = nil
        isAccessoryEnabled = nil
        onWebInputFocused = nil
        onCompanionItems = nil
        onPageDidFinish = nil

        onDownloadDidStart = nil
        onDownloadDecideDestination = nil
        onDownloadDidFinish = nil
        onDownloadDidFail = nil
        onDownloadRequested = nil

        isAppActiveClosure = nil
        webViewHandle = nil
        webView = nil
        policyBridge = nil
    }

    internal var snapshotState: TabWebStoreState {
        TabWebStoreState(
            pageTitle: pageTitle,
            currentURL: currentURL,
            canGoBack: canGoBack,
            canGoForward: canGoForward,
            estimatedProgress: estimatedProgress,
            isLoading: isLoading
        )
    }

    // MARK: - WebView
    /// Underlying WKWebView owned by this store.
    ///
    /// This is exposed primarily for legacy bridging (e.g. embedding inside
    /// a platform-specific view). UI and ViewModel code must not retain or
    /// configure this view directly; all lifecycle and delegate management
    /// are handled inside TabWebStore.
    public private(set) var webView: WKWebView?
    public private(set) var webViewHandle: WebViewHandle?
    internal var policyBridge: WebKitPolicyBridge?

    internal private(set) var currentContextRoute: WebContextRoute = .paneDefault

    private var attachedWebViewPool: WebViewPool?
    // MARK: - UI Callbacks (bridged from UI layer)
    public var onWebViewBecameFirstResponder: (() -> Void)?
    public var isAccessoryEnabled: (() -> Bool)?

    // MARK: - Callbacks
    public var onWebInputFocused: (() -> Void)?
    public var onCompanionItems: (([CompanionItem]) -> Void)?
    public var onPageDidFinish: ((URL?, String) -> Void)?
    public var onDownloadDidStart: ((WKDownload) -> Void)?
    public var onDownloadDecideDestination: ((WKDownload, URLResponse, String) -> URL?)?
    public var onDownloadDidFinish: ((URL?) -> Void)?
    public var onDownloadDidFail: ((Error) -> Void)?

    /// Called when a navigation response should be treated as a download.
    ///
    /// This is emitted from WKNavigationDelegate interception points so the app can
    /// manage downloads (progress, resume, background sessions).
    public var onDownloadRequested: ((URLRequest, URLResponse) -> Void)?

    /// Emitted when the Safari-like policy layer evaluates a navigation decision.
    ///
    /// The app is expected to append this event to the session journal.
    public var onPolicyDecisionEvent: ((SessionJournalEvent) -> Void)?

    /// Emitted when WebKit requests a new window (e.g. target=_blank) and policy decides
    /// it should open in a new tab/window at the app layer.
    public var onOpenInNewTabRequested: ((URLRequest) -> Void)?

    /// Emitted after WebKit has *committed* a navigation (WKNavigationDelegate.didCommit).
    ///
    /// This is the canonical hook for session journaling of navigation commits.
    public var onNavigationCommitted: ((URL?) -> Void)?

    // MARK: - Internal
    internal var companionTask: Task<Void, Never>?
    internal var pendingProcessRecoverTask: Task<Void, Never>?
    internal var processRecoverAttempts: Int = 0
    internal var lastProcessTerminateAt: CFTimeInterval = 0
    internal var lastProcessRecoverAt: CFTimeInterval = 0
    internal var lastProcessRecoverDelayForTesting: Double = 0
    internal private(set) var isInvalidated = false
    internal var bypassSmartSplitOnce = false
    internal var lastScrollSuggestAt: CFTimeInterval = 0
    internal var lastScrollSuggestY: CGFloat = 0
    internal var lastSuggestedPageKey: String = ""
    internal var pendingScrollSuggestTask: Task<Void, Never>?
    internal var latestScrollSuggestY: CGFloat = 0
    internal var titleObservation: NSKeyValueObservation?
    internal var urlObservation: NSKeyValueObservation?
    internal var canGoBackObservation: NSKeyValueObservation?
    internal var canGoForwardObservation: NSKeyValueObservation?
    internal var estimatedProgressObservation: NSKeyValueObservation?
    internal var isLoadingObservation: NSKeyValueObservation?
    private var runningTasks: [UUID: Task<Void, Never>] = [:]
    @available(iOS 14.5, *)
    private var downloadDestinations: [ObjectIdentifier: URL] = [:]
    internal let contentBlockerManager: (any ContentBlockingProviding)?
    internal weak var websitePreferencesProvider: (any WebsitePreferencesProviding)?
    internal var pendingWebPermissionDecisions: [UUID: (WKPermissionDecision) -> Void] = [:]
    internal var webPermissionPromptObserver: NSObjectProtocol?
    internal let logger = Logger(subsystem: "SafariLikeKit", category: "TabWebStore")
    private let defaultSearchEngineURL: URL
    private var _searchEngineURL: URL
    public var searchEngineURL: URL {
        get { _searchEngineURL }
        set { _searchEngineURL = newValue }
    }
    /// Threading: Call on the main actor.
    public init(
        tabID: UUID,
        windowID: String,
        paneID: String,
        role: Role,
        configuration: WKWebViewConfiguration,
        defaultHomeURLString: String,
        searchEngineURL: URL = DefaultURLs.SearchEngine.googleQuery,
        contentBlockerManager: (any ContentBlockingProviding)? = nil,
        websitePreferencesProvider: (any WebsitePreferencesProviding)? = nil,
        browsingProfile: BrowsingProfile = .regular,
        configFactory: WebViewConfigurationFactory
    ) {
        self.tabID = tabID
        self.windowID = windowID
        self.paneID = paneID
        self.role = role
        self.browsingProfile = browsingProfile
        self.defaultSearchEngineURL = searchEngineURL
        self._searchEngineURL = searchEngineURL
        self.contentBlockerManager = contentBlockerManager
        self.websitePreferencesProvider = websitePreferencesProvider
        self.configFactory = configFactory

        // Do not create WKWebView at init. Will be created lazily when tab is activated/visible.
        self.webView = nil
        self.webViewHandle = nil

        #if DEBUG
        if debugLogEnabled {
            Diagnostics.logDebug(
                "[TabWebStore] CREATE WebView instance=\(webViewPointerString(webView)) tabRole=\(role)",
                subsystem: .web,
                category: "TabWebStore"
            )
        }
        #endif

        super.init()
    }

    /// Threading: Call on the main actor.
    public func activate() async {
        await activate(using: attachedWebViewPool)
    }

    /// Threading: Call on the main actor.
    public func activate(using pool: WebViewPool? = nil) async {
        let pool = pool ?? .shared
        // Lazily create WKWebView only when tab is activated/visible
        if webView == nil {
            uxRestoreController.markRestoring()
            let privacyMode: WebPrivacyMode = (browsingProfile == .private) ? .private : .regular
            let seedURL = currentURL ?? DefaultURLs.aboutBlank
            let navCtx = NavigationContext(
                tabID: tabID,
                windowID: windowID,
                url: seedURL,
                isMainFrame: true,
                hasUserGesture: false,
                navigationType: .other,
                sourceURL: nil
            )
            let route = await WebContextRouter.shared.routeContext(
                for: navCtx,
                paneID: PaneID(rawValue: paneID) ?? .primary,
                privacyMode: privacyMode
            )
            currentContextRoute = route
            let context = WebContextManager.shared.context(
                windowID: windowID,
                paneID: paneID,
                tabID: tabID,
                privacyMode: privacyMode,
                route: route,
                maxIsolatedPerPane: 2
            )
            attachedWebViewPool = pool
            let webView = pool.acquireWebView(for: tabID, context: context)
            self.webContext = context
            self.webView = webView
            self.webViewHandle = WebViewHandle(webView: webView, retain: false)

            // WebView is now physically present/attachable; reflect that in render state.
            context.renderState = .active

            // Install scripts/handlers/delegates now that the WebView exists.
            // Avoid auto-loading here; TabCoordinator decides what to load.
            configureWebViewAfterInit(defaultHomeURLString: DefaultURLs.aboutBlank.absoluteString)

            context.ensureInitialLoad()
        }

        // Activation is idempotent; keep render state consistent even if WebView was already created.
        self.webContext?.renderState = .active
        setupObservers()
        // No teardown or nil assignment here. Only setup.
    }

    /// Threading: Call on the main actor.
    public func deactivate() {
        deactivate(releaseMode: .warm)
    }

    public enum WebViewReleaseMode: Sendable {
        /// Release to the engine idle pool when possible.
        case warm
        /// Release aggressively (do not keep in the idle pool).
        case cold
    }

    /// Teardown observers + detach WebKit delegates/scripts before releasing.
    private func deactivate(releaseMode: WebViewReleaseMode) {
        teardownObservers()
        invalidateWebViewCore()

        // Downgrade render state before detaching and nil-ing references.
        self.webContext?.renderState = .suspended

        let pool = attachedWebViewPool ?? .shared
        switch releaseMode {
        case .warm:
            pool.releaseTab(tabID)
        case .cold:
            pool.invalidateTab(tabID)
        }
        self.webView = nil
        self.webViewHandle = nil
        self.webContext = nil
        WebContextManager.shared.tearDownContext(windowID: windowID, paneID: paneID, tabID: tabID)
    }

    /// Detach the WKWebView aggressively.
    ///
    /// Useful for memory pressure / background-long scenarios.
    public func deactivateCold() {
        deactivate(releaseMode: .cold)
    }

    // MARK: - Render Budget Helpers

    /// Detach the underlying `WKWebView` while keeping the store alive.
    ///
    /// This maps to a Safari-like "freeze / snapshot-only" behavior.
    public func freezeWebView() {
        guard webViewHandle != nil else { return }
        deactivate()
    }

    /// Ensure a `WKWebView` exists for this store.
    ///
    /// Note: This does not enforce any global budgeting; callers should
    /// apply a policy at a higher layer.
    public func ensureWebViewAttached() async {
        guard webViewHandle == nil else { return }
        await activate(using: attachedWebViewPool)
    }

    /// Evict the `WKWebView` if it exists.
    ///
    /// Current implementation evicts only the view (not the store) by detaching
    /// the web view. More aggressive eviction (destroying the store) is handled
    /// by owners (e.g. `TabRegistry.remove(tabID:)`).
    public func evictWebViewIfNeeded() {
        freezeWebView()
    }
    /// Threading: Call on the main actor.
    public func invalidate() async {
        if self.isInvalidated {
            self.logger.debug("TabWebStore invalidate called more than once role=\(String(describing: self.role))")
            return
        }

        self._invalidateSynchronously()

        self.logger.debug("TabWebStore invalidate role=\(String(describing: self.role))")
        #if DEBUG
        if self.debugLogEnabled {
            Diagnostics.logDebug(
                "[TabWebStore] INVALIDATE WebView instance=\(webViewPointerString(self.webView)) role=\(self.role)",
                subsystem: .web,
                category: "TabWebStore"
            )
        }
        #endif
        
        // 1) Reset internal async work and navigation-related state.
        resetForReuseInternal(defaultHomeURLString: defaultSearchEngineURL.absoluteString)

        // 2) Detach delegates/scripts and stop loads.
        invalidateWebViewCore()

        // 3) Teardown any observers and scroll-related work.
        teardownObservers()

        // 4) Release WKWebView via pool bookkeeping.
        let pool = attachedWebViewPool ?? .shared
        pool.invalidateTab(tabID)

        // 3) Fully tear down the WKWebView core.
        invalidateWebViewCore()

        // 4) Clear all remaining delegates/handlers and app state closures.
        onWebViewBecameFirstResponder = nil
        isAccessoryEnabled = nil
        onWebInputFocused = nil
        onCompanionItems = nil
        // 5) Clear all download/page callbacks and app state closures.
        onPageDidFinish = nil
        onDownloadDidStart = nil
        onDownloadDecideDestination = nil
        onDownloadDidFinish = nil
        onDownloadDidFail = nil
        onDownloadRequested = nil
        isAppActiveClosure = nil
        
        // 6) Finally, clear state observers so no more callbacks are delivered.
        stateObservers.removeAll()

        if let observer = webPermissionPromptObserver {
            NotificationCenter.default.removeObserver(observer)
            webPermissionPromptObserver = nil
        }
        pendingWebPermissionDecisions.removeAll()
    }

    /// Minimal, synchronous cleanup for deinit only. Do not touch actor-isolated or async state here.
    private func _invalidateSynchronously() {
        isInvalidated = true
        // Do not access WKWebView, observers, or any async state here.
        // Only clear simple properties if needed.
    }

    /// Internal reset hook used by owners that wish to recycle an existing
    /// WebView for the same logical tab.
    ///
    /// Responsibilities:
    /// - Cancel and clear internal async tasks associated with the previous
    ///   navigation lifecycle.
    /// - Reset navigation-related state via existing update helpers so that
    ///   observers see a consistent "empty" tab state.
    ///
    /// This method deliberately does *not* touch WKWebView delegates, KVO
    /// bindings, or injected scripts. Callers are responsible for invoking
    /// the appropriate WebView teardown / reconfiguration helpers afterwards.
    @MainActor
    internal func resetForReuseInternal(defaultHomeURLString _: String) {
        // 1) Cancel all running tasks and companion work.
        runningTasks.values.forEach { $0.cancel() }
        runningTasks.removeAll()
        companionTask?.cancel()
        companionTask = nil
        pendingProcessRecoverTask?.cancel()
        pendingProcessRecoverTask = nil
        pendingScrollSuggestTask?.cancel()
        pendingScrollSuggestTask = nil

        // 2) Reset navigation-related state via existing helpers so
        //    observers receive a single, consistent reset notification.
        updatePageTitle(nil)
        updateCurrentURL(nil)
        updateCanGoBack(false)
        updateCanGoForward(false)
        updateEstimatedProgress(0.0)
        updateIsLoading(false)
    }

    // Move deinit to the end of the class, just before the closing brace
    deinit {
        if !isInvalidated {
            #if DEBUG
            Diagnostics.logError(
                "[TabWebStore] deinit: deallocated without invalidate() (role=\(String(describing: self.role)))",
                subsystem: .runtime,
                category: "TabWebStore"
            )
            #endif
            Self.deinitLogger.error("TabWebStore deallocated without invalidate()")
            isInvalidated = true
            // Fail-safe: clear closures only (non-actor)
            isAppActiveClosure = nil
            // stateObservers is @MainActor, do not touch here
            // Do NOT touch WebKit APIs, do NOT await, do NOT Task { ... }
        }
    }
}
// MARK: - WebNavigator conformance
extension TabWebStore: WebNavigator {
    public func goBack() {
        guard !isInvalidated, let handle = webViewHandle, handle.isAlive else { return }
        handle.goBack()
    }

    public func goForward() {
        guard !isInvalidated, let handle = webViewHandle, handle.isAlive else { return }
        handle.goForward()
    }

    public func reload() {
        guard !isInvalidated, let handle = webViewHandle, handle.isAlive else { return }
        handle.reload()
    }

    public func stopLoading() {
        guard !isInvalidated, let handle = webViewHandle, handle.isAlive else { return }
        handle.stopLoading()
    }

    public func load(_ url: URL, force: Bool) {
        guard !isInvalidated, let handle = webViewHandle, handle.isAlive else { return }
        if force { setBypassSmartSplitOnce() }
        handle.load(url: url)
    }

    public func load(_ request: URLRequest, force: Bool) {
        guard !isInvalidated, let handle = webViewHandle, handle.isAlive else { return }
        if force { setBypassSmartSplitOnce() }
        handle.load(request: request)
    }
}

// MARK: - Private helpers
extension TabWebStore {
    @discardableResult
    internal func runTask(_ block: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        if isInvalidated || Task.isCancelled {
            return Task { }
        }
        let id = UUID()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.runningTasks[id] = nil }
            guard !self.isInvalidated, !Task.isCancelled else { return }
            await block()
        }
        runningTasks[id] = task
        return task
    }
    func _cancelCompanionTask() {
        companionTask?.cancel()
        companionTask = nil
    }
}
