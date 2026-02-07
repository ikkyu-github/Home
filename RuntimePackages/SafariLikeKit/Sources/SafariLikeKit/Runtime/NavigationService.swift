import Foundation
import SafariLikeCoreKit
import OSLog
// BUILD-PERF-AUDIT(2026-01-21): Compile hotspot (navigation gateway referenced by many domains).
// Keep this file protocol-driven and avoid pulling UI/WebKit dependencies into the navigation layer.
// MARK: - ⚠️ Domain ↔ WebView Boundary
// TODO: NavigationService is the gateway between Domain logic and WebView layer
// Domain logic (SplitBrowserNavigationDomain, ViewModel) must NEVER access WKWebView directly.
// All WebView operations must route through NavigationService to ensure:
// - Consistent logging and monitoring
// - Rate limiting and validation
// - Nil-safety checks (activeStore existence)
// - Future navigation policies (authentication, confirmation dialogs, etc.)
// MARK: - Omnibox-facing Navigation Abstraction
/// Narrow navigation interface used by the address bar / omnibox.
///
/// This allows runtime and UI components to depend on a protocol
/// instead of the concrete NavigationService type.
@MainActor
extension NavigationService: NavigationHandling {}
/// Represents a navigation action for logging and monitoring purposes.
@MainActor
enum NavigationAction: Equatable {
    case goBack
    case goForward
    case reload
    case stopLoading
    case loadURLString(String)
    case loadURL(URL)
    case loadRequest(String) // URL string representation
    var description: String {
        switch self {
        case .goBack:
            return "goBack"
        case .goForward:
            return "goForward"
        case .reload:
            return "reload"
        case .stopLoading:
            return "stopLoading"
        case .loadURLString(let urlString):
            return "loadURLString(\(urlString))"
        case .loadURL(let url):
            return "loadURL(\(url.absoluteString))"
        case .loadRequest(let urlString):
            return "loadRequest(\(urlString))"
        }
    }
}
/// Represents a single navigation lifecycle for a tab.
///
/// A context moves through the following pipeline:
///   start → commit → finish / fail / cancel
///
/// It also owns any async Tasks spawned as part of the navigation so they
/// can be cancelled when the tab is closed or the navigation becomes invalid.
@MainActor
final class NavigationLifecycleContext {
    enum Stage {
        case started
        case committed
        case finished
        case failed
        case cancelled
    }
    let id = UUID()
    let action: NavigationAction
    let tabID: UUID?
    private(set) var stage: Stage = .started
    private weak var pluginHost: PluginHost?
    private weak var nextGenManagerRef: NextGenPluginManager?
    private var tasks: [Task<Void, Never>] = []
    init(
        action: NavigationAction,
        tabID: UUID?,
        pluginHost: PluginHost?,
        nextGenManager: NextGenPluginManager?
    ) {
        self.action = action
        self.tabID = tabID
        self.pluginHost = pluginHost
        self.nextGenManagerRef = nextGenManager
    }
    func register(task: Task<Void, Never>) {
        tasks.append(task)
    }
    func markCommitted() {
        guard stage == .started else { return }
        stage = .committed
    }
    func markFinished() {
        guard stage == .committed || stage == .started else { return }
        stage = .finished
        tasks.removeAll()
    }
    func markFailed() {
        guard stage != .failed && stage != .cancelled else { return }
        stage = .failed
        cancelTasks()
    }
    func cancel() {
        guard stage != .finished && stage != .cancelled else { return }
        stage = .cancelled
        cancelTasks()
    }
    private func cancelTasks() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }
    // MARK: - Simple navigation plugin hooks (PluginHost)
    func notifyNavigationWillStart(url: URL) async {
        await pluginHost?.navigationWillStart(url: url)
    }
    func notifyNavigationDidFinish(url: URL) async {
        await pluginHost?.navigationDidFinish(url: url)
    }
    func notifyNavigationDidFail(url: URL, error: Error) async {
        await pluginHost?.navigationDidFail(url: url, error: error)
    }
    // MARK: - Next-gen plugin manager access
    func nextGenManager() -> NextGenPluginManager? {
        nextGenManagerRef
    }
}
/// Central hub for all WebView navigation operations.
/// 
/// This service acts as the single authoritative point for all navigation actions.
/// WebViews should NEVER be accessed directly for navigation from Views, ViewModels,
/// or other Domains. All navigation must route through this service.
///
/// Advantages:
/// - Single entry point for logging/monitoring all navigation
/// - Enforces nil-safety (checks activeStore before navigation)
/// - Allows for navigation policies (rate limiting, validation, etc.)
/// - Simplifies debugging and testing
/// - Prevents multiple concurrent navigation requests
///
@MainActor
final class NavigationService {
    // MARK: - Logger
    static let logger = Logger(subsystem: "SafariLikeKit", category: "NavigationService")
    /// The TabManager that provides access to the active store
    private(set) weak var tabManager: TabManager?
    /// Plugin host for managing plugin lifecycle. Resolved lazily from TabManager
    /// so that NavigationService always sees the latest host instance.
    var pluginHost: PluginHost? {
        tabManager?.pluginHost
    }
    /// Track in-flight navigation contexts keyed by context ID.
    var activeContexts: [UUID: NavigationLifecycleContext] = [:]
    /// Track last navigation time for rate limiting (optional)
    var lastNavigationTime: Date = .distantPast
    let navigationMinInterval: TimeInterval = 0.05 // 50ms minimum between navigations
    // MARK: - Callbacks
    var onNavigationRequested: ((NavigationAction) -> Void)?
    var onNavigationFailed: ((NavigationAction, Error?) -> Void)?
    var onNavigationSucceeded: ((NavigationAction) -> Void)?
    // MARK: - Init
    init(tabManager: TabManager) {
        self.tabManager = tabManager
    }
    deinit {
        // Ensure any in-flight navigation work is cancelled when the
        // service is torn down (e.g. window/scene is closed).
        let contexts = Array(activeContexts.values)
        Task { @MainActor in
            contexts.forEach { $0.cancel() }
        }
    }
}
@MainActor
extension NavigationService {
    /// Returns the active store for navigation if and only if the
    /// TabManager reports a stable, bound active tab.
    internal func activeStoreForNavigation(action: NavigationAction) -> SafariLikeCoreKit.TabWebStore? {
        guard let tabManager = tabManager else {
            onNavigationFailed?(action, nil)
            return nil
        }
        switch tabManager.activeBindingState {
        case .bound:
            break
        case .binding(let id):
            Self.logger.debug("Navigation \(action.description) blocked: active tab is binding (id=\(id))")
            onNavigationFailed?(action, nil)
            return nil
        case .unbinding(let id):
            Self.logger.debug("Navigation \(action.description) blocked: active tab is unbinding (id=\(id))")
            onNavigationFailed?(action, nil)
            return nil
        case .unbound:
            Self.logger.debug("Navigation \(action.description) blocked: no active tab bound")
            onNavigationFailed?(action, nil)
            return nil
        @unknown default:
            Self.logger.error("Navigation \(action.description) blocked: unknown activeBindingState encountered")
            onNavigationFailed?(action, nil)
            return nil
        }
        guard let store = tabManager.activeStore else {
            Self.logger.error("Navigation \(action.description) failed: activeStore is nil while binding state is bound")
            onNavigationFailed?(action, nil)
            return nil
        }
        return store
    }
    internal func canNavigate() -> Bool {
        // Rate limiting: prevent rapid-fire navigation requests
        let timeSinceLastNav = Date().timeIntervalSince(lastNavigationTime)
        if timeSinceLastNav < navigationMinInterval {
            return false
        }
        return true
    }
    internal func recordNavigation() {
        lastNavigationTime = Date()
    }
}
@MainActor
extension NavigationService {
    /// Access to plugin manager for registering/unregistering plugins
    public var plugins: NextGenPluginManager? {
        currentPluginManager()
    }
    /// Resolve the plugin manager for the current window/tab context.
    internal func currentPluginManager() -> NextGenPluginManager? {
        guard let pluginHost = pluginHost else {
            Self.logger.error("Plugin context unavailable: pluginHost is nil; navigation plugins will not run")
            return nil
        }
        guard let tabManager = tabManager else {
            Self.logger.error("Plugin context unavailable: tabManager has been deallocated; navigation plugins will not run")
            return nil
        }
        guard let activeTabID = tabManager.sessionStore.selectedTabID else {
            Self.logger.debug("Plugin context unavailable: no active tab selected; navigation plugins will not run")
            return nil
        }
        return pluginHost.getOrCreatePluginManager(for: activeTabID.uuidString)
    }
    /// Helper to execute async operation with timeout
    internal func withTimeoutSeconds<T>(
        _ seconds: TimeInterval,
        _ operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Start the main operation
            group.addTask {
                try await operation()
            }
            // Start timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            // Return first result (either operation or timeout)
            if let result = try await group.next() {
                group.cancelAll()
                return result
            }
            throw TimeoutError()
        }
    }
}
@MainActor
extension NavigationService {
    // MARK: - Public Navigation API
    /// Navigate back in the active tab's history.
    func goBack() {
        let action: NavigationAction = .goBack
        guard let store = activeStoreForNavigation(action: action) else { return }
        guard let tabManager = tabManager else { return }
        let tabID = tabManager.activeTabID ?? tabManager.sessionStore.selectedTabID
        guard let tabID else { return }
        guard tabManager.sessionStore.canGoBack(tabID: tabID) else { return }
        guard let targetURLString = tabManager.sessionStore.requestGoBack(tabID: tabID) else { return }
        guard let context = makeContext(for: action, needsNextGenPlugins: false) else { return }
        guard canNavigate() else {
            // Rate limiting in effect
            return
        }
        onNavigationRequested?(action)
        context.markCommitted()

        if store.webViewHandle?.isAlive == true, store.state.canGoBack {
            store.goBack()
        } else {
            // WebKit history is missing (e.g. post-eviction). Force-attach and load the target.
            if store.webViewHandle?.isAlive != true {
                tabManager.forceAttachActiveTabWebView(reason: "navigation.goBack")
            }
            loadURLString(targetURLString, in: store, force: true)
        }
        onNavigationSucceeded?(action)
        recordNavigation()
        finishContext(context)
    }
    /// Navigate forward in the active tab's history.
    func goForward() {
        let action: NavigationAction = .goForward
        guard let store = activeStoreForNavigation(action: action) else { return }
        guard let tabManager = tabManager else { return }
        let tabID = tabManager.activeTabID ?? tabManager.sessionStore.selectedTabID
        guard let tabID else { return }
        guard tabManager.sessionStore.canGoForward(tabID: tabID) else { return }
        guard let targetURLString = tabManager.sessionStore.requestGoForward(tabID: tabID) else { return }
        guard let context = makeContext(for: action, needsNextGenPlugins: false) else { return }
        guard canNavigate() else { return }
        onNavigationRequested?(action)
        context.markCommitted()

        if store.webViewHandle?.isAlive == true, store.state.canGoForward {
            store.goForward()
        } else {
            if store.webViewHandle?.isAlive != true {
                tabManager.forceAttachActiveTabWebView(reason: "navigation.goForward")
            }
            loadURLString(targetURLString, in: store, force: true)
        }
        onNavigationSucceeded?(action)
        recordNavigation()
        finishContext(context)
    }
    /// Reload the active tab.
    func reload() {
        let action: NavigationAction = .reload
        guard let store = activeStoreForNavigation(action: action) else { return }
        let navigator: WebNavigator = store
        guard let context = makeContext(for: action, needsNextGenPlugins: false) else { return }
        guard canNavigate() else { return }
        onNavigationRequested?(action)
        context.markCommitted()
        navigator.reload()
        onNavigationSucceeded?(action)
        recordNavigation()
        finishContext(context)
    }
    /// Stop loading the active tab.
    func stopLoading() {
        let action: NavigationAction = .stopLoading
        guard let store = activeStoreForNavigation(action: action) else { return }
        let navigator: WebNavigator = store
        guard let context = makeContext(for: action, needsNextGenPlugins: false) else { return }
        onNavigationRequested?(action)
        context.markCommitted()
        navigator.stopLoading()
        onNavigationSucceeded?(action)
        finishContext(context)
    }
    /// Load a URL string with smart handling (scheme inference, search fallback).
    func loadURLString(_ urlString: String, force: Bool = false) {
        let action: NavigationAction = .loadURLString(urlString)
        guard let store = activeStoreForNavigation(action: action) else { return }
        let navigator: WebNavigator = store
        // Normalize user/favorite inputs before plugin interception and before passing to WebKit.
        // This prevents "no scheme" favorites/search from being treated as invalid and cancelled.
        guard let resolved = OmniboxParser.resolve(urlString, searchEngineTemplateURL: store.searchEngineURL) else {
            return
        }
        let resolvedURLString = resolved.resolvedURLString
        guard canNavigate() else { return }
        guard let context = makeContext(for: action, needsNextGenPlugins: true) else { return }

        // Record user intent so a future WebKit commit can reconcile with durable history.
        if let tabID = tabManager?.activeTabID ?? tabManager?.sessionStore.selectedTabID {
            tabManager?.sessionStore.recordUserRequestedLoad(tabID: tabID, urlString: resolvedURLString, replaceCurrent: false)
        }
        // Resolve plugin manager for current window/tab context.
        guard let manager = context.nextGenManager() else {
            // No valid plugin context; fall back to plain navigation without plugins.
            onNavigationRequested?(action)
            context.markCommitted()
            navigator.load(resolvedURLString, force: force)
            onNavigationSucceeded?(action)
            recordNavigation()
            finishContext(context)
            return
        }
        // [PLUGIN INTERCEPTION] Execute plugin hooks asynchronously and bind
        // their lifetime to this navigation context.
        let interceptTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            let request = NavigationRequest(
                url: resolvedURLString,
                method: "GET",
                headers: [:],
                isMainFrame: true
            )
            // Publish a start event for plugins subscribed via PluginContext.
            self.tabManager?.pluginSessionProvider.updateCurrentNavigationRequest(request)
            self.tabManager?.pluginSessionProvider.publish(.navigationDidStart(request))
            // Allow any dynamically registered interceptors to participate.
            if let provider = self.tabManager?.pluginSessionProvider {
                let dynamicResponse = await provider.evaluateInterceptors(request)
                switch dynamicResponse {
                case .allow:
                    break
                case .block:
                    self.onNavigationFailed?(action, nil)
                    self.tabManager?.pluginSessionProvider.publish(
                        .navigationDidFail(request, PluginError.invalidConfiguration("Navigation blocked"))
                    )
                    self.failContext(context)
                    return
                case .cancel:
                    self.onNavigationFailed?(action, nil)
                    self.tabManager?.pluginSessionProvider.publish(
                        .navigationDidFail(request, PluginError.invalidConfiguration("Navigation cancelled"))
                    )
                    self.cancelContext(context)
                    return
                case .redirect(let redirectURL):
                    self.loadURL(redirectURL, force: force)
                    self.cancelContext(context)
                    return
                case .synthesize:
                    self.onNavigationFailed?(action, nil)
                    self.tabManager?.pluginSessionProvider.publish(
                        .navigationDidFail(request, PluginError.invalidConfiguration("Synthetic response not supported"))
                    )
                    self.failContext(context)
                    return
                @unknown default:
                    break
                }
            }
            do {
                // 2. Call plugins with willLoadURL hook (with timeout)
                let result = try await self.withTimeoutSeconds(5.0) {
                    await manager.willLoadURL(request)
                }
                // 3. Handle InterceptionResponse from plugins
                switch result {
                case .allow:
                    // Browser continues normally
                    break
                case .block:
                    // Plugin blocked navigation
                    self.onNavigationFailed?(action, nil)
                    self.failContext(context)
                    return  // Stop here
                case .cancel:
                    // Plugins requested to cancel navigation (equivalent to user stop)
                    self.onNavigationFailed?(action, nil)
                    self.cancelContext(context)
                    return
                case .redirect(let redirectURL):
                    // Plugin redirected to different concrete URL
                    self.loadURL(redirectURL, force: force)
                    self.cancelContext(context)
                    return  // Restart with redirect target
                case .synthesize:
                    // Plugin provides synthetic response (not yet implemented in WebView)
                    // For now, treat as allowed
                    break
                @unknown default:
                    // Future-proofing: treat unknown responses as `.allow`.
                    break
                }
                // 4. Proceed with normal navigation
                guard let activeStore = self.tabManager?.activeStore, activeStore === store else {
                    // Tab was closed/switched between async calls
                    self.onNavigationFailed?(action, nil)
                    self.cancelContext(context)
                    return
                }
                self.onNavigationRequested?(action)
                context.markCommitted()
                let activeNavigator: WebNavigator = activeStore
                activeNavigator.load(resolvedURLString, force: force)
                // 5. Notify plugins of successful navigation after small delay
                let didLoadTask = Task { [weak self] in
                    guard let self = self else { return }
                    do {
                        // Preserve existing behaviour: small post-load delay
                        try await Task.sleep(nanoseconds: 500_000_000)
                        try await self.withTimeoutSeconds(5.0) {
                            await manager.didLoadURL(request)
                        }
                        self.tabManager?.pluginSessionProvider.publish(.navigationDidFinish(request))
                        self.onNavigationSucceeded?(action)
                        self.recordNavigation()
                        self.finishContext(context)
                    } catch is TimeoutError {
                        // Plugin notification timeout – navigation already committed.
                        self.tabManager?.pluginSessionProvider.publish(.navigationDidFinish(request))
                        self.finishContext(context)
                    } catch {
                        // Plugin notification errors don't fail the navigation
                        // (already loaded successfully)
                        self.tabManager?.pluginSessionProvider.publish(.navigationDidFinish(request))
                        self.finishContext(context)
                    }
                }
                context.register(task: didLoadTask)
            } catch is TimeoutError {
                // Plugin hook timed out - block navigation to prevent hanging UI
                self.onNavigationFailed?(action, nil)
                self.tabManager?.pluginSessionProvider.publish(.navigationDidFail(request, PluginError.timeout))
                self.failContext(context)
            } catch {
                // Plugin hook error - log and proceed with navigation
                // (plugins shouldn't crash the browser)
                self.tabManager?.pluginSessionProvider.publish(.navigationDidFail(request, error))
                guard let activeStore = self.tabManager?.activeStore, activeStore === store else {
                    self.onNavigationFailed?(action, nil)
                    self.cancelContext(context)
                    return
                }
                self.onNavigationRequested?(action)
                context.markCommitted()
                let activeNavigator: WebNavigator = activeStore
                activeNavigator.load(resolvedURLString, force: force)
                // Preserve original behaviour: do not call success callbacks here.
                self.finishContext(context)
            }
        }
        context.register(task: interceptTask)
    }
    /// Load a URL string into a specific store.
    ///
    /// This is used by lifecycle helpers (e.g. tab activation) that already
    /// resolved the concrete store and must avoid coupling to `TabWebStore.load`.
    func loadURLString(
        _ urlString: String,
        in store: SafariLikeCoreKit.TabWebStore,
        force: Bool = false
    ) {
        store.load(urlString, force: force)
    }
    /// Load a concrete URL directly (no normalization).
    func loadURL(_ url: URL, force: Bool = false) {
        let action: NavigationAction = .loadURL(url)
        guard let store = activeStoreForNavigation(action: action) else { return }
        let navigator: WebNavigator = store
        guard canNavigate() else { return }
        guard let context = makeContext(for: action, needsNextGenPlugins: false) else { return }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            let navRequest = NavigationRequest(
                url: url.absoluteString,
                method: "GET",
                headers: [:],
                isMainFrame: true
            )
            self.tabManager?.pluginSessionProvider.updateCurrentNavigationRequest(navRequest)
            self.tabManager?.pluginSessionProvider.publish(.navigationDidStart(navRequest))
            if let provider = self.tabManager?.pluginSessionProvider {
                let dynamicResponse = await provider.evaluateInterceptors(navRequest)
                switch dynamicResponse {
                case .allow:
                    break
                case .block:
                    self.onNavigationFailed?(action, nil)
                    self.tabManager?.pluginSessionProvider.publish(
                        .navigationDidFail(navRequest, PluginError.invalidConfiguration("Navigation blocked"))
                    )
                    self.failContext(context)
                    return
                case .cancel:
                    self.onNavigationFailed?(action, nil)
                    self.tabManager?.pluginSessionProvider.publish(
                        .navigationDidFail(navRequest, PluginError.invalidConfiguration("Navigation cancelled"))
                    )
                    self.cancelContext(context)
                    return
                case .redirect(let redirectURL):
                    self.loadURL(redirectURL, force: force)
                    self.cancelContext(context)
                    return
                case .synthesize:
                    self.onNavigationFailed?(action, nil)
                    self.tabManager?.pluginSessionProvider.publish(
                        .navigationDidFail(navRequest, PluginError.invalidConfiguration("Synthetic response not supported"))
                    )
                    self.failContext(context)
                    return
                @unknown default:
                    break
                }
            }
            if let host = self.pluginHost {
                let request = URLRequest(url: url)
                let allowed = await host.shouldAllowNavigation(request)
                guard allowed else {
                    self.tabManager?.pluginSessionProvider.publish(
                        .navigationDidFail(navRequest, PluginError.invalidConfiguration("Navigation blocked by policy"))
                    )
                    self.finishContext(context)
                    return
                }
            }
            guard let activeStore = self.tabManager?.activeStore, activeStore === store else {
                self.finishContext(context)
                return
            }
            if let host = self.pluginHost {
                await context.notifyNavigationWillStart(url: url)
                _ = host // keep reference alive within scope
            }
            self.onNavigationRequested?(action)
            context.markCommitted()
            navigator.load(url, force: force)
            self.onNavigationSucceeded?(action)
            self.recordNavigation()
            self.tabManager?.pluginSessionProvider.publish(.navigationDidFinish(navRequest))
            if let host = self.pluginHost {
                await context.notifyNavigationDidFinish(url: url)
                _ = host
            }
            self.finishContext(context)
        }
        context.register(task: task)
    }
    /// Load a prepared URLRequest directly.
    func loadRequest(_ request: URLRequest, force: Bool = false) {
        let action = NavigationAction.loadRequest(request.url?.absoluteString ?? "")
        guard let store = activeStoreForNavigation(action: action) else { return }
        let navigator: WebNavigator = store
        guard canNavigate() else { return }
        guard let context = makeContext(for: action, needsNextGenPlugins: false) else { return }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            let navRequest = NavigationRequest(
                url: request.url?.absoluteString ?? "",
                method: request.httpMethod ?? "GET",
                headers: request.allHTTPHeaderFields ?? [:],
                isMainFrame: true
            )
            self.tabManager?.pluginSessionProvider.updateCurrentNavigationRequest(navRequest)
            self.tabManager?.pluginSessionProvider.publish(.navigationDidStart(navRequest))
            if let provider = self.tabManager?.pluginSessionProvider {
                let dynamicResponse = await provider.evaluateInterceptors(navRequest)
                switch dynamicResponse {
                case .allow:
                    break
                case .block:
                    self.onNavigationFailed?(action, nil)
                    self.tabManager?.pluginSessionProvider.publish(
                        .navigationDidFail(navRequest, PluginError.invalidConfiguration("Navigation blocked"))
                    )
                    self.failContext(context)
                    return
                case .cancel:
                    self.onNavigationFailed?(action, nil)
                    self.tabManager?.pluginSessionProvider.publish(
                        .navigationDidFail(navRequest, PluginError.invalidConfiguration("Navigation cancelled"))
                    )
                    self.cancelContext(context)
                    return
                case .redirect(let redirectURL):
                    self.loadURL(redirectURL, force: force)
                    self.cancelContext(context)
                    return
                case .synthesize:
                    self.onNavigationFailed?(action, nil)
                    self.tabManager?.pluginSessionProvider.publish(
                        .navigationDidFail(navRequest, PluginError.invalidConfiguration("Synthetic response not supported"))
                    )
                    self.failContext(context)
                    return
                @unknown default:
                    break
                }
            }
            if let host = self.pluginHost {
                let allowed = await host.shouldAllowNavigation(request)
                guard allowed else {
                    self.tabManager?.pluginSessionProvider.publish(
                        .navigationDidFail(navRequest, PluginError.invalidConfiguration("Navigation blocked by policy"))
                    )
                    self.finishContext(context)
                    return
                }
            }
            guard let activeStore = self.tabManager?.activeStore, activeStore === store else {
                self.finishContext(context)
                return
            }
            if let url = request.url {
                await context.notifyNavigationWillStart(url: url)
            }
            self.onNavigationRequested?(action)
            context.markCommitted()
            navigator.load(request, force: force)
            self.onNavigationSucceeded?(action)
            self.recordNavigation()
            self.tabManager?.pluginSessionProvider.publish(.navigationDidFinish(navRequest))
            if let url = request.url {
                await context.notifyNavigationDidFinish(url: url)
            }
            self.finishContext(context)
        }
        context.register(task: task)
    }
    // MARK: - Context lifecycle
    func cancelNavigations(forTabID id: UUID) {
        for (key, context) in activeContexts where context.tabID == id {
            context.cancel()
            activeContexts[key] = nil
        }
    }
    /// Create a new NavigationLifecycleContext for the current active tab.
    private func makeContext(
        for action: NavigationAction,
        needsNextGenPlugins: Bool
    ) -> NavigationLifecycleContext? {
        guard let tabManager = tabManager else { return nil }
        let tabID = tabManager.sessionStore.selectedTabID
        let manager: NextGenPluginManager?
        if needsNextGenPlugins {
            manager = currentPluginManager()
        } else {
            manager = nil
        }
        let context = NavigationLifecycleContext(
            action: action,
            tabID: tabID,
            pluginHost: pluginHost,
            nextGenManager: manager
        )
        activeContexts[context.id] = context
        return context
    }
    /// Mark a context as finished and remove it from the active map.
    private func finishContext(_ context: NavigationLifecycleContext) {
        context.markFinished()
        activeContexts[context.id] = nil
    }
    /// Mark a context as failed and remove it from the active map.
    private func failContext(_ context: NavigationLifecycleContext) {
        context.markFailed()
        activeContexts[context.id] = nil
    }
    /// Cancel a context (e.g. when tab is closed or navigation invalidated)
    /// and remove it from the active map.
    private func cancelContext(_ context: NavigationLifecycleContext) {
        context.cancel()
        activeContexts[context.id] = nil
    }
}
// MARK: - Timeout Error
struct TimeoutError: Error, LocalizedError {
    var errorDescription: String? { "Operation timed out" }
}
