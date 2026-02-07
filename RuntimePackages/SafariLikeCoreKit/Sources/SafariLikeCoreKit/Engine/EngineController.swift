// ARCH-AUDIT(2026-01-22): ✅ FIXED: Removed UIKit import. Memory pressure now flows through MemoryPressureObserver protocol.

import Foundation
import WebKit

/// App-wide singleton that centralizes WebKit runtime control.
///
/// Policy:
/// - No View / TabManager / arbitrary code should construct `WKWebView` directly.
/// - All WebView creation must go through `WebViewPool` (scene-owned `WebContext`).
///
/// Threading:
/// - WebKit objects must be created and mutated on the main actor.
@MainActor
public final class EngineController {
    public static var shared: EngineController { _shared }
    private static var _shared: EngineController = EngineController()

    /// SAFE SINGLETON:
    /// - Process-wide WebKit engine coordinator.
    /// - Must NOT store or index per-window/scene/tab mutable state.
    /// - Per-scene/per-tab WebContext ownership belongs in higher layers (e.g. WebContextManager/TabWebStore).

    /// Configure the process-wide shared engine.
    ///
    /// Clean-architecture rule: UIKit must not be referenced in SafariLikeCoreKit.
    /// Memory-pressure signals are delivered via an injected `EngineMemoryPressureSource`
    /// implemented in UI-layer modules.
    public static func configureShared(
        memoryPressureSource: (any EngineMemoryPressureSource)? = nil
    ) {
        _shared = EngineController(
            memoryPressureSource: memoryPressureSource
        )
    }

    struct PoolKey: Hashable, Sendable {
        let privacyMode: WebPrivacyMode
        let windowID: String?
        let paneID: String?

        init(privacyMode: WebPrivacyMode, windowID: String? = nil, paneID: String? = nil) {
            self.privacyMode = privacyMode
            self.windowID = windowID
            self.paneID = paneID
        }
    }

    public enum ReleaseReason: Sendable, Equatable {
        case deactivated
        case invalidated
        case memoryPressure
        case background
        case explicit(String)
    }

    public enum MemoryPressureLevel: Sendable, Equatable {
        case warning
        case critical
    }

    private let memoryPressureSource: (any EngineMemoryPressureSource)?

    /// Observers notified whenever a new `WKWebView` is created by the engine.
    ///
    /// This is the primary extension point for higher layers (e.g. SafariLikeKit)
    /// to apply WebView-bound features (resource plugins, instrumentation, etc.)
    /// without CoreKit depending on those modules.
    private var webViewCreatedObservers: [UUID: (@MainActor (UUID, WKWebView) -> Void)] = [:]

    /// Observers notified when a tab's primary WebView reports that the page became interactive.
    ///
    /// Definition: the WebView has finished the initial document load and a lightweight JS probe
    /// confirmed `document.readyState` is at least `interactive`.
    private var webViewInteractiveObservers: [UUID: (@MainActor (UUID) -> Void)] = [:]

    /// Observers notified when a tab's Web content process terminates.
    private var webContentProcessTerminationObservers: [UUID: (@MainActor (UUID) -> Void)] = [:]

    // MARK: - Memory Pressure Telemetry

    public enum MemoryPressureStep: Sendable, Equatable {
        case freezeTab(tabID: UUID)
        case evictTab(tabID: UUID)
        case releaseWebView(tabID: UUID, reason: ReleaseReason)
    }

    public enum MemoryPressureEvent: Sendable, Equatable {
        case received(level: MemoryPressureLevel)
        case mitigationStarted
        case step(MemoryPressureStep)
        case stable
    }

    private var memoryPressureObservers: [UUID: (@MainActor (MemoryPressureEvent) -> Void)] = [:]
    private var memoryPressureEpoch: UInt64 = 0

    private init(
        memoryPressureSource: (any EngineMemoryPressureSource)? = nil
    ) {
        self.memoryPressureSource = memoryPressureSource

        self.memoryPressureSource?.setHandler { [weak self] level in
            Task { @MainActor [weak self] in
                self?.handleMemoryPressure(level: level)
            }
        }
    }

    // MARK: - Web Content Process Termination

    public func addWebContentProcessTerminationObserver(
        _ observer: @escaping @MainActor (UUID) -> Void
    ) -> UUID {
        let token = UUID()
        webContentProcessTerminationObservers[token] = observer
        return token
    }

    public func removeWebContentProcessTerminationObserver(_ token: UUID) {
        webContentProcessTerminationObservers[token] = nil
    }

    public func notifyWebContentProcessDidTerminate(tabID: UUID) {
        for observer in webContentProcessTerminationObservers.values {
            observer(tabID)
        }
    }

    /// Best-effort warm-up: pre-create 1 WebView per privacy mode and return it to the idle pool.
    public func prewarmWebKit() {
        let regularConfig = makeWebViewConfiguration(profile: .regular)
        let regularWebView = WebViewPool.makeWebView(configuration: regularConfig)
        WebConfigurationProvider.shared.register(regularWebView)
        WebConfigurationProvider.shared.unregister(regularWebView)

        let privateConfig = makeWebViewConfiguration(profile: .private)
        let privateWebView = WebViewPool.makeWebView(configuration: privateConfig)
        WebConfigurationProvider.shared.register(privateWebView)
        WebConfigurationProvider.shared.unregister(privateWebView)
    }

    /// Acquire (or create) a `WKWebView` for a tab.
    ///
    /// Note: For profile-specific configuration, prefer the internal overload that
    /// accepts an explicit `WKWebViewConfiguration`.
    @available(*, unavailable, message: "Use TabRegistry/WebViewPool via SceneRuntimeContext (scene-owned WebContext)")
    public func acquireWebView(for tabID: UUID) -> WKWebView {
        #if DEBUG
        assertionFailure("[EngineController] acquireWebView(for:) is deprecated. Own WebContext per-scene/tab and acquire via WebViewPool.acquireWebView(for:context:). tabID=\(tabID)")
        #endif

        // Best-effort compatibility: create a fresh WebView without retaining per-tab state.
        let configuration = makeWebViewConfiguration(profile: .regular)
        let webView = WebViewPool.makeWebView(configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        WebConfigurationProvider.shared.register(webView)

        if webViewCreatedObservers.isEmpty == false {
            for observer in webViewCreatedObservers.values {
                observer(tabID, webView)
            }
        }
        return webView
    }

    /// Single source of truth for constructing `WKWebViewConfiguration`.
    ///
    /// Policy (locked):
    /// - `.private` → `WKWebsiteDataStore.nonPersistent()`
    /// - `.regular` → `WKWebsiteDataStore.default()`
    /// - processPool: system default (do not set)
    @MainActor
    public func makeWebViewConfiguration(profile: BrowsingProfile) -> WKWebViewConfiguration {
        WebConfigurationProvider.shared.makeWebViewConfiguration(profile: profile)
    }

    /// CoreKit-internal: acquire using an explicit configuration (profile-aware).
    @available(*, unavailable, message: "Use TabRegistry/WebViewPool via SceneRuntimeContext (scene-owned WebContext)")
    internal func acquireWebView(for tabID: UUID, configuration: WKWebViewConfiguration) -> WKWebView {
        #if DEBUG
        assertionFailure("[EngineController] acquireWebView(for:configuration:) is deprecated. Own WebContext per-scene/tab and acquire via WebViewPool.acquireWebView(for:context:). tabID=\(tabID)")
        #endif

        // Best-effort compatibility: create a fresh WebView without retaining per-tab state.
        let webView = WebViewPool.makeWebView(configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        WebConfigurationProvider.shared.register(webView)

        if webViewCreatedObservers.isEmpty == false {
            for observer in webViewCreatedObservers.values {
                observer(tabID, webView)
            }
        }
        return webView
    }

    /// Register an observer notified when the engine creates new `WKWebView` instances.
    /// - Returns: A token used to remove the observer.
    public func addWebViewCreatedObserver(
        _ observer: @escaping @MainActor (UUID, WKWebView) -> Void
    ) -> UUID {
        let token = UUID()
        webViewCreatedObservers[token] = observer
        return token
    }

    /// Remove a previously registered observer.
    public func removeWebViewCreatedObserver(_ token: UUID) {
        webViewCreatedObservers.removeValue(forKey: token)
    }

    /// Register an observer notified when a tab's WebView becomes interactive.
    /// - Returns: A token used to remove the observer.
    public func addWebViewInteractiveObserver(
        _ observer: @escaping @MainActor (UUID) -> Void
    ) -> UUID {
        let token = UUID()
        webViewInteractiveObservers[token] = observer
        return token
    }

    /// Remove a previously registered interactive observer.
    public func removeWebViewInteractiveObserver(_ token: UUID) {
        webViewInteractiveObservers.removeValue(forKey: token)
    }

    /// Internal: notify observers that a tab's WebView became interactive.
    internal func notifyWebViewInteractive(tabID: UUID) {
        guard webViewInteractiveObservers.isEmpty == false else { return }
        for observer in webViewInteractiveObservers.values {
            observer(tabID)
        }
    }

    // MARK: - Memory Pressure Observers

    public func addMemoryPressureObserver(
        _ observer: @escaping @MainActor (MemoryPressureEvent) -> Void
    ) -> UUID {
        let token = UUID()
        memoryPressureObservers[token] = observer
        return token
    }

    public func removeMemoryPressureObserver(_ token: UUID) {
        memoryPressureObservers.removeValue(forKey: token)
    }

    /// Higher layers can call this to record policy steps (freeze/evict) that
    /// are not directly performed by CoreKit.
    public func notifyMemoryPressureStep(_ step: MemoryPressureStep) {
        notifyMemoryPressure(.step(step))
    }

    private func notifyMemoryPressure(_ event: MemoryPressureEvent) {
        guard memoryPressureObservers.isEmpty == false else { return }
        for observer in memoryPressureObservers.values {
            observer(event)
        }
    }

    /// Release a `WKWebView` previously acquired for a tab.
    public func releaseWebView(for tabID: UUID, reason: ReleaseReason) {
        #if DEBUG
        assertionFailure("[EngineController] releaseWebView(for:) is deprecated. WebView lifecycle is owned by WebViewPool/TabWebStore; release via pool.invalidateTab/releaseTab and tear down WebContext via WebContextManager. tabID=\(tabID) reason=\(reason)")
        #endif
        _ = tabID
        _ = reason
    }

    /// Handle memory pressure centrally.
    ///
    /// Current behavior: on critical pressure, drop all cached webviews.
    /// Higher-level layers may additionally call `releaseWebView` for specific tabs.
    public func handleMemoryPressure(level: MemoryPressureLevel) {
        memoryPressureEpoch &+= 1
        let epoch = memoryPressureEpoch

        notifyMemoryPressure(.received(level: level))
        notifyMemoryPressure(.mitigationStarted)

        switch level {
        case .warning:
            // Keep current caches; higher layers may decide to trim.
            scheduleMemoryStableCheck(epoch: epoch)
            return
        case .critical:
            // CoreKit engine does not own per-tab state; higher layers should respond by
            // deactivating tabs and trimming per-scene pools/contexts.
            scheduleMemoryStableCheck(epoch: epoch)
        }
    }

    /// Context-aware overload used by lifecycle coordinators.
    ///
    /// Important: the engine remains process-wide; `SceneRuntimeContext` is provided only
    /// to enforce that scene-related lifecycle flows carry an explicit context.
    public func handleMemoryPressure(level: MemoryPressureLevel, context: SceneRuntimeContext) {
        _ = context
        handleMemoryPressure(level: level)
    }

    private func scheduleMemoryStableCheck(epoch: UInt64) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Treat "stable" as: no new memory pressure received for a short grace window.
            // This is best-effort and intentionally passive.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard self.memoryPressureEpoch == epoch else { return }
            self.notifyMemoryPressure(.stable)
        }
    }

    /// Prepare WebKit runtime for backgrounding.
    public func prepareForBackground() {
        // IMPORTANT: Do not tear down/"release" WebViews on background transitions.
        // Backgrounding is not a correctness signal, and detaching delegates here can
        // break TabWebStore ownership assumptions and lead to white-screen on return.
        // Memory pressure paths (handleMemoryPressure(.critical)) remain the only
        // automatic eviction mechanism.
    }

    /// Context-aware overload used by lifecycle coordinators.
    public func prepareForBackground(context: SceneRuntimeContext) {
        _ = context
        prepareForBackground()
    }

    /// Restore WebKit runtime after returning to foreground.
    public func restoreAfterForeground() {
        // No-op by default; web views are recreated lazily on demand.
    }

    /// Context-aware overload used by lifecycle coordinators.
    public func restoreAfterForeground(context: SceneRuntimeContext) {
        _ = context
        restoreAfterForeground()
    }

    private func prepareForReuse(_ webView: WKWebView) {
        webView.stopLoading()
        detachDelegates(webView)

        if let url = URL(string: "about:blank") {
            webView.load(URLRequest(url: url))
        }
    }

    private func detachDelegates(_ webView: WKWebView) {
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }
}

// NOTE: UIKit/AppKit-specific memory pressure observation belongs in UI modules.
