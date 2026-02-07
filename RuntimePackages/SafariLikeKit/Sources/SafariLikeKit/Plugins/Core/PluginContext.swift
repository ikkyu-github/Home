import Foundation
import SafariLikeContracts
import SafariLikeCoreKit
/// Immutable context passed to plugins for safe browser API access.
///
/// **Design Principle:** Plugins only access what they declared they need.
/// - Capabilities checked before context creation
/// - API access gated by capability requirements
/// - No access to internal state (WebView, ViewModel, UIKit)
/// - All operations are read-only or explicitly declared side effects
///
/// **Thread Safety:**
/// - `PluginContext` is nonisolated and `Sendable`
/// - Execution context lives in the underlying services (e.g. MainActor hops)
/// - Context is immutable after creation
/// - Plugin lifecycle controlled by browser
///
/// **Capability Gating:**
/// ```swift
/// // Plugin declared: .navigationRead
/// // ✅ Can call:
/// try await context.currentTabURL()
/// try await context.onNavigationEvent { ... }
///
/// // ❌ Cannot call:
/// try await context.interceptNavigation { ... }  // requires .navigationIntercept
/// ```
///
/// **Usage Lifetime:**
/// - Created when plugin loads: `onLoad(context:)`
/// - Valid during entire plugin lifetime
/// - Invalidated when plugin unloads (methods throw PluginError.unloaded)
/// - Reference kept in plugin (strong capture OK, context is immutable)
///
/// **Security Model:**
/// 1. **No WebView access** - Can't manipulate web rendering
/// 2. **No UIKit access** - Can't control UI layer
/// 3. **No ViewModel access** - Can't access browser state
/// 4. **No file access** - Can't read/write app files
/// 5. **No process access** - Can't spawn processes
/// 6. **No network access** - Can't make direct HTTP requests
///
/// All plugin actions go through declared capabilities.
public struct PluginContext: Sendable, BrowserPluginContext, NavigationReadContext {
    public typealias AuditHandler = @Sendable (PluginAuditEvent) -> Void
    /// Stable identifier of the plugin instance this context belongs to.
    public let pluginID: String
    /// Unique identifier of the browser window this context belongs to
    public let windowID: String
    /// Current tab identifier (if applicable)
    ///
    /// **Note:** May change if user switches tabs. Plugin should not cache this.
    /// Use `onTabChanged` callback to react to tab changes.
    public let tabID: String
    /// Capabilities this context can use (gated API access)
    let declaredCapabilities: Set<PluginCapability>
    /// User-granted permissions for this plugin (deny-by-default).
    private let grantedPermissions: Set<PluginPermission>
    /// Optional audit sink invoked for each sensitive API use.
    private let auditHandler: AuditHandler?
    /// Service boundary backing navigation + content script surfaces.
    ///
    /// Note: this is a service boundary (execution context belongs to the service).
    private let sessionProvider: (any PluginSessionProvider)?
    /// Read-only query services for additional plugin surfaces.
    ///
    /// These are intentionally protocol-based so PluginContext stays a façade.
    private let tabQueryService: (any TabQueryService)?
    private let historyQueryService: (any HistoryQueryService)?
    private let bookmarksQueryService: (any BookmarksQueryService)?
    /// Initialization (internal only - created by plugin system)
    ///
    /// - Parameters:
    ///   - windowID: Browser window identifier
    ///   - tabID: Current tab identifier
    ///   - capabilities: Declared capabilities for gating
    ///   - session: Reference to browser session (weak)
    init(
        pluginID: String,
        windowID: String,
        tabID: String,
        capabilities: Set<PluginCapability>,
        grantedPermissions: Set<PluginPermission> = [],
        auditHandler: AuditHandler? = nil,
        session: PluginSessionProvider?,
        tabQueryService: TabQueryService,
        historyQueryService: HistoryQueryService,
        bookmarksQueryService: BookmarksQueryService
    ) {
        self.pluginID = pluginID
        self.windowID = windowID
        self.tabID = tabID
        self.declaredCapabilities = capabilities
        self.grantedPermissions = grantedPermissions
        self.auditHandler = auditHandler
        self.sessionProvider = session
        self.tabQueryService = tabQueryService
        self.historyQueryService = historyQueryService
        self.bookmarksQueryService = bookmarksQueryService
    }
    // MARK: - Minimal Safe Plugin Surface
    /// Stable identifier for the browser window as a UUID.
    ///
    /// If `windowID` is not a UUID string, this falls back to a
    /// deterministic UUID derived from the windowID string.
    public var browserID: UUID {
        if let parsed = UUID(uuidString: windowID) {
            return parsed
        }
        // Deterministic fallback to keep identity stable.
        let bytes = Array(windowID.utf8)
        var hash: UInt64 = 1469598103934665603
        for b in bytes {
            hash ^= UInt64(b)
            hash &*= 1099511628211
        }
        // Expand 64-bit hash into 128-bit UUID bytes.
        var uuidBytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            uuidBytes[i] = UInt8((hash >> UInt64(i * 8)) & 0xff)
            uuidBytes[i + 8] = uuidBytes[i] ^ 0xA5
        }
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40 // v4
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80 // variant
        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
    }
    /// Whether the current browsing session is private.
    ///
    /// Defaults to false when the session is unavailable.
    public var isPrivateMode: Bool {
        sessionProvider?.getIsPrivateMode() ?? false
    }
    /// Minimal navigation event stream.
    public var navigationEvents: NavigationEventBus {
        NavigationEventBus { handler in
            try await self.onNavigationEvent(handler: handler)
        }
    }
    /// Minimal snapshot of settings that plugins may read.
    public var settings: BrowserSettingsSnapshot {
        BrowserSettingsSnapshot(
            isContentBlockingEnabled: sessionProvider?.getIsContentBlockingEnabled() ?? true,
            userAgentMode: sessionProvider?.getUserAgentMode() ?? .mobile,
            searchEngineURLTemplate: sessionProvider?.getSearchEngineURLTemplate() ?? ""
        )
    }
    // MARK: - Capability Validation
    /// Checks if this context has a specific capability
    ///
    /// - Parameter capability: Capability to check
    /// - Returns: true if capability was declared, false otherwise
    public func hasCapability(_ capability: PluginCapability) -> Bool {
        guard declaredCapabilities.contains(capability) else { return false }
        guard let permission = PluginPermission(capability: capability) else { return true }
        return grantedPermissions.contains(permission)
    }
    // MARK: - Navigation Read API
    /// Returns current URL of active tab (requires `.navigationRead`)
    ///
    /// - Returns: Current URL string, or nil if no URL is loaded
    /// - Throws: `PluginError.capabilityRequired(.navigationRead)` if not declared
    ///
    /// **Note:** URL may change due to redirects, history navigation, or XHR.
    /// Don't cache this value; query fresh when needed.
    ///
    /// **Example:**
    /// ```swift
    /// let currentURL = try await context.currentTabURL()
    /// if currentURL?.contains("example.com") == true {
    ///     // Handle example.com pages
    /// }
    /// ```
    public func currentTabURL() async throws -> String? {
        try requireCapability(.navigationRead, audit: .currentTabURL)
        guard let session = sessionProvider else {
            throw PluginError.sessionUnloaded
        }
        return await session.getCurrentTabURL()
    }
    /// Returns metadata about current navigation request (requires `.navigationRead`)
    ///
    /// - Returns: NavigationRequest details (URL, method, headers), or nil if idle
    /// - Throws: `PluginError.capabilityRequired(.navigationRead)` if not declared
    ///
    /// **What's Included:**
    /// - URL: Full request URL
    /// - method: HTTP method (GET, POST, etc.)
    /// - headers: All HTTP headers
    /// - isMainFrame: Whether this is the main page or a subframe
    ///
    /// **What's NOT Included:**
    /// - Request body (for safety)
    /// - Cookies (not needed, browser sends them)
    /// - SSL certificate details (handled by browser)
    ///
    /// **Example:**
    /// ```swift
    /// if let request = try await context.navigationRequest() {
    ///     print("Loading: \(request.url)")
    ///     print("Method: \(request.method)")
    /// }
    /// ```
    public func navigationRequest() async throws -> NavigationRequest? {
        try requireCapability(.navigationRead, audit: .navigationRequest)
        guard let session = sessionProvider else {
            throw PluginError.sessionUnloaded
        }
        return await session.getCurrentNavigationRequest()
    }
    // MARK: - Tab Observation API
    public func openTabs() async throws -> [PluginTabSnapshot] {
        try requireCapability(.tabObservation, audit: .openTabs)
        guard let service = tabQueryService else {
            throw PluginError.sessionUnloaded
        }
        return try await service.openTabs()
    }
    // MARK: - History Read API
    public func recentHistory(limit: Int) async throws -> [PluginHistoryItem] {
        try requireCapability(.historyRead, audit: .recentHistory)
        guard let service = historyQueryService else {
            throw PluginError.sessionUnloaded
        }
        return try await service.recentHistory(limit: limit)
    }
    // MARK: - Bookmarks Read API
    public func bookmarks() async throws -> [PluginBookmarkItem] {
        try requireCapability(.bookmarksRead, audit: .bookmarks)
        guard let service = bookmarksQueryService else {
            throw PluginError.sessionUnloaded
        }
        return try await service.bookmarks()
    }
    /// Subscribe to navigation events (requires `.navigationRead`)
    ///
    /// - Parameter handler: Called on each navigation event
    /// - Returns: Subscription token (retain to keep subscription active)
    ///
    /// **Events:**
    /// - `navigationDidStart(request)`: New navigation initiated
    /// - `navigationDidFinish(request)`: Navigation completed successfully
    /// - `navigationDidFail(request, error)`: Navigation failed
    /// - `tabDidChange(from:to:)`: User switched tabs
    ///
    /// **Subscription Lifetime:**
    /// - Automatically unsubscribed when token is deallocated
    /// - Store token in plugin state to keep subscription active
    /// - Multiple handlers can subscribe simultaneously
    ///
    /// **Thread Safety:**
    /// - Handlers called on @MainActor
    /// - Safe to update plugin state in handler
    ///
    /// **Example:**
    /// ```swift
    /// var navigationSubscription: PluginEventSubscription?
    ///
    /// func onLoad(context: PluginContext) async throws {
    ///     navigationSubscription = try await context.onNavigationEvent { event in
    ///         switch event {
    ///         case .navigationDidStart(let request):
    ///             print("Started: \(request.url)")
    ///         case .navigationDidFinish(let request):
    ///             print("Finished: \(request.url)")
    ///         case .navigationDidFail(let request, let error):
    ///             print("Failed: \(error)")
    ///         case .tabDidChange(from: let old, to: let new):
    ///             print("Switched from tab \(old) to \(new)")
    ///         }
    ///     }
    /// }
    /// ```
    public func onNavigationEvent(
        handler: @escaping @MainActor (NavigationEvent) -> Void
    ) async throws -> PluginEventSubscription {
        try requireCapability(.navigationRead, audit: .subscribeNavigationEvents)
        guard let session = sessionProvider else {
            throw PluginError.sessionUnloaded
        }
        return await session.subscribeToNavigationEvents(handler: handler)
    }
    // MARK: - Navigation Intercept API
    /// Intercept navigation requests before they load (requires `.navigationIntercept`)
    ///
    /// - Parameter handler: Called for each navigation request
    /// - Returns: Subscription token (retain to keep interception active)
    ///
    /// **Handler Signature:**
    /// ```swift
    /// (NavigationRequest) async -> InterceptionResponse
    /// ```
    ///
    /// **Responses:**
    /// - `allow`: Let navigation proceed as-is
    /// - `redirect(to:)`: Change target URL
    /// - `block`: Cancel navigation (stay on current page)
    /// - `synthesize(response:)`: Return synthetic response instead
    ///
    /// **Use Cases:**
    /// - Ad blocking: `block` requests to ad-serving domains
    /// - Malware prevention: `block` or `redirect` suspicious URLs
    /// - Content filtering: `redirect` to safe alternatives
    /// - Request modification: `redirect` with modified URL
    ///
    /// **Performance:**
    /// - Handler called synchronously before navigation
    /// - Keep handler lightweight (no heavy computation)
    /// - Slow handlers may freeze UI briefly
    ///
    /// **Example:**
    /// ```swift
    /// var interceptSubscription: PluginEventSubscription?
    ///
    /// func onLoad(context: PluginContext) async throws {
    ///     try requireCapability(.navigationIntercept)
    ///
    ///     interceptSubscription = try await context.interceptNavigation { request in
    ///         // Block requests to ad domains
    ///         if request.url.contains("ads.example.com") {
    ///             return .block
    ///         }
    ///         // Redirect to HTTPS
    ///         if request.url.hasPrefix("http://") {
    ///             let secure = request.url.replacingOccurrences(of: "http://", with: "https://")
    ///             return .redirect(to: secure)
    ///         }
    ///         // Allow everything else
    ///         return .allow
    ///     }
    /// }
    /// ```
    ///
    /// - Throws: `PluginError.capabilityRequired(.navigationIntercept)` if not declared
    public func interceptNavigation(
        handler: @escaping @MainActor (NavigationRequest) async -> InterceptionResponse
    ) async throws -> PluginEventSubscription {
        try requireCapability(.navigationIntercept, audit: .interceptNavigation)
        guard let session = sessionProvider else {
            throw PluginError.sessionUnloaded
        }
        return await session.registerNavigationInterceptor(handler: handler)
    }
    // MARK: - Content Script API
    /// Inject JavaScript into page at load time (requires `.contentScripts`)
    ///
    /// - Parameters:
    ///   - scriptID: Unique identifier for this script (for later removal)
    ///   - source: JavaScript source code
    ///   - timing: When to inject (atDocumentStart, afterDocumentEnd)
    ///
    /// - Throws: `PluginError.capabilityRequired(.contentScripts)` if not declared
    ///
    /// **Timing:**
    /// - `atDocumentStart`: Runs before any page scripts
    /// - `afterDocumentEnd`: Runs after page load completes
    ///
    /// **Scope:**
    /// - Scripts run in page context (not sandboxed)
    /// - Full access to page DOM, XHR, cookies, etc.
    /// - Plugin responsible for security implications
    ///
    /// **Limitations:**
    /// - Can't access plugin APIs from injected script
    /// - Can communicate via window.postMessage to plugin context
    /// - Scripts can't modify plugin state directly
    ///
    /// **Example:**
    /// ```swift
    /// // Inject dark mode CSS
    /// let darkModeCSS = """
    /// body { background: #1e1e1e; color: #e0e0e0; }
    /// """
    ///
    /// try await context.injectScript(
    ///     scriptID: "darkMode",
    ///     source: darkModeCSS,
    ///     timing: .afterDocumentEnd
    /// )
    /// ```
    public func injectScript(
        scriptID: String,
        source: String,
        timing: InjectionTiming = .afterDocumentEnd
    ) async throws {
        try requireCapability(.contentScripts, audit: .injectScript)
        guard let session = sessionProvider else {
            throw PluginError.sessionUnloaded
        }
        try await session.injectScript(scriptID: scriptID, source: source, timing: timing)
    }
    /// Remove previously injected script (requires `.contentScripts`)
    ///
    /// - Parameter scriptID: Identifier from `injectScript(scriptID:source:timing:)`
    /// - Throws: `PluginError.capabilityRequired(.contentScripts)` if not declared
    ///
    /// **Effect:**
    /// - Script won't be injected into future pages
    /// - Already-injected scripts remain active (can't undo that)
    ///
    /// **Example:**
    /// ```swift
    /// try await context.removeScript(scriptID: "darkMode")
    /// ```
    public func removeScript(scriptID: String) async throws {
        try requireCapability(.contentScripts, audit: .removeScript)
        guard let session = sessionProvider else {
            throw PluginError.sessionUnloaded
        }
        try await session.removeScript(scriptID: scriptID)
    }
    // MARK: - Private Helpers
    /// Validates that a capability is declared
    ///
    /// - Parameter capability: Capability to require
    /// - Throws: PluginError if not declared
    private func requireCapability(
        _ capability: PluginCapability,
        audit action: PluginAuditAction,
        url: String? = nil
    ) throws {
        guard declaredCapabilities.contains(capability) else {
            throw PluginError.capabilityRequired(capability)
        }
        let requiredPermission = PluginPermission(capability: capability)
        if let requiredPermission, grantedPermissions.contains(requiredPermission) == false {
            throw PluginError.permissionRequired(requiredPermission)
        }
        auditHandler?(PluginAuditEvent(
            pluginID: pluginID,
            windowID: windowID,
            tabID: tabID,
            action: action,
            capability: capability,
            requiredPermission: requiredPermission,
            url: url
        ))
    }
}
// MARK: - Supporting Types now live in SafariLikeCoreKit
/// Token representing an active subscription.
///
/// Hold this token to keep subscription active.
/// When deallocated, subscription automatically ends.
public final class PluginEventSubscription: Sendable {
    private let unsubscribe: @Sendable @MainActor () async -> Void
    init(unsubscribe: @escaping @Sendable @MainActor () async -> Void) {
        self.unsubscribe = unsubscribe
    }
    deinit {
        // Cleanup happens when token is deallocated.
        // Capture the unsubscribe closure directly to avoid retaining self
        // inside the Task and to keep lifetime bounded to this deinit.
        let unsubscribe = self.unsubscribe
        Task { @MainActor in
            await unsubscribe()
        }
    }
}
// MARK: - Error Types now live in SafariLikeCoreKit (PluginError)
// MARK: - Session Provider Protocol
/// Provides safe browser session API to plugins (internal)
///
/// Plugins never see this directly. PluginContext uses it to implement public APIs.
public protocol PluginSessionProvider: AnyObject, Sendable {
    func getCurrentTabURL() async -> String?
    func getCurrentNavigationRequest() async -> NavigationRequest?
    func subscribeToNavigationEvents(
        handler: @escaping @MainActor (NavigationEvent) -> Void
    ) async -> PluginEventSubscription
    func registerNavigationInterceptor(
        handler: @escaping @MainActor (NavigationRequest) async -> InterceptionResponse
    ) async -> PluginEventSubscription
    func injectScript(scriptID: String, source: String, timing: InjectionTiming) async throws
    func removeScript(scriptID: String) async throws
    // Minimal safe data points
    func getIsPrivateMode() -> Bool
    func getIsContentBlockingEnabled() -> Bool
    func getUserAgentMode() -> BrowserSettingsSnapshot.UserAgentMode
    func getSearchEngineURLTemplate() -> String
}
