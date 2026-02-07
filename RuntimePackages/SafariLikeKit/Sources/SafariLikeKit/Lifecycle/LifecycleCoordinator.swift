import Foundation
import Combine
import SafariLikeCoreKit
import UIKit
import os
/// Central lifecycle orchestrator for SafariLikeKit.
///
/// Layers:
/// 1) AppLifecycle
///    - launch
///    - background
///    - terminate
/// 2) WindowLifecycle
///    - scene connect/disconnect
///    - foreground/background
/// 3) BrowserRuntime
///    - tab active
///    - tab suspended
///    - webview attached/detached
///
/// Goal: lifecycle is controlled from one place.
@MainActor
public final class LifecycleCoordinator: ObservableObject {
    public enum AppLifecycleEvent: Sendable {
        case launch
        case background
        case terminate
    }
    public enum WindowLifecycleEvent: Sendable {
        case connect
        case disconnect
        case foreground
        case background
    }
    public enum BrowserRuntimeEvent: Sendable {
        case tabActivated(tabID: UUID)
        case tabSuspended(tabID: UUID)
        case webViewAttached(tabID: UUID)
        case webViewDetached(tabID: UUID)
        case rootViewAppeared
    }
    private let appLifecycle: AppLifecycleCoordinator
    private static let logger = Logger(subsystem: "SafariLikeKit", category: "LifecycleCoordinator")
    @MainActor
    private struct SceneEntry {
        let sceneID: String
        let windowID: BrowserWindowID
        let session: BrowserSceneSession
        let windowContext: BrowserWindowContext
        let coreContext: SafariLikeCoreKit.SceneRuntimeContext
        var didRootViewAppear: Bool = false
        var viewModel: SplitBrowserViewModel { session.viewModel }
        var tabManager: TabManager { session.viewModel.tabManager }
    }
    private let windowRegistry = WindowRegistry()
    private var entry: SceneEntry?
    private var memoryWarningObserver: NSObjectProtocol?
    public init(appLifecycle: AppLifecycleCoordinator) {
        self.appLifecycle = appLifecycle
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                Self.logger.warning("Memory warning received; discarding non-visible web views")
                guard let entry = self.entry else { return }
                EngineController.shared.handleMemoryPressure(level: .critical, context: entry.coreContext)
                Task {
                    await PolicyCenter.shared.noteSceneEvent("memoryWarning", context: entry.coreContext)
                }
                entry.tabManager.handleMemoryPressure(level: .critical, source: "UIApplication.didReceiveMemoryWarning")
            }
        }
    }
    // MARK: - Read-only Introspection (Debug/Diagnostics)
    /// Returns the per-window context for a given view model when registered.
    ///
    /// Read-only helper intended for debug/diagnostics UI.
    func windowContext(for viewModel: SplitBrowserViewModel) -> BrowserWindowContext? {
        guard let entry, ObjectIdentifier(entry.viewModel) == ObjectIdentifier(viewModel) else { return nil }
        return entry.windowContext
    }

    /// Read-only helper intended for debug/diagnostics UI and unit tests.
    func coreContext(for viewModel: SplitBrowserViewModel) -> SafariLikeCoreKit.SceneRuntimeContext? {
        guard let entry, ObjectIdentifier(entry.viewModel) == ObjectIdentifier(viewModel) else { return nil }
        return entry.coreContext
    }
    // MARK: - Registration
    /// Register a scene/window with the coordinator.
    ///
    /// Call this once per scene connection, after creating the session.
    public func registerScene(
        sceneID: String,
        windowID: BrowserWindowID,
        session: BrowserSceneSession
    ) {
        if let existing = entry {
            Self.logger.error(
                "🚨 registerScene called more than once; ignoring. existingSceneID=\(existing.sceneID, privacy: .public) newSceneID=\(sceneID, privacy: .public)"
            )
            return
        }
        let manager = session.viewModel.tabManager
        let pluginHost = manager.pluginHost
        let windowIDCopy = manager.windowID
        let normalTabRegistryCopy = manager.normalTabRegistry
        let privateTabRegistryCopy = manager.privateTabRegistry
        let context = windowRegistry.onSceneConnect(
            windowID: windowID.value,
            pluginMetricsProvider: {
                await MainActor.run {
                    guard let host = pluginHost else { return nil }
                    return host.pluginMetricsSnapshot()
                }
            }
        )
        let coreContext = SafariLikeCoreKit.SceneRuntimeContext(
            sceneIdentifier: sceneID,
            windowID: windowIDCopy,
            tabRegistry: normalTabRegistryCopy,
            privateTabRegistry: privateTabRegistryCopy,
            siteHeuristicsStore: appLifecycle.siteHeuristicsStore,
            websiteDataPolicy: .default
        )
        let entry = SceneEntry(
            sceneID: sceneID,
            windowID: windowID,
            session: session,
            windowContext: context,
            coreContext: coreContext
        )
        // Configure per-window fault handling.
        let faultManager = FaultManager(
            windowID: windowID.value,
            metrics: context.browserMetrics,
            disablePlugin: { pluginID in
                // Best-effort: disable via PluginHost when available (persists enablement state),
                // otherwise fall back to immediate registry disable.
                if let host = entry.tabManager.pluginHost {
                    Task { @MainActor in
                        await host.disablePlugin(id: pluginID)
                    }
                } else {
                    context.pluginRegistry.disable(pluginID: pluginID)
                }
            },
            discardWebView: { tabID in
                // Discard active pane web views to recover from WebKit/runtime faults.
                // If a specific tabID is provided, prefer that; else discard active panes.
                let ids: [UUID] = {
                    if let tabID { return [tabID] }
                    if entry.tabManager.isSplitViewEnabled {
                        return [entry.tabManager.leftTabID, entry.tabManager.rightTabID].compactMap { $0 }
                    }
                    return [entry.tabManager.activeTabID].compactMap { $0 }
                }()
                for id in ids {
                    entry.tabManager.requestDeactivateWebView(tabID: id, mode: .cold, reason: "fault.discard")
                    entry.tabManager.destroyRuntime(for: id)
                }
            },
            requestUIRerender: {
                entry.viewModel.requestUIRerender()
            }
        )
        context.faultManager = faultManager
        context.pluginRegistry.faultManager = faultManager
        self.entry = entry
        appLifecycle.registerScene(sceneID: sceneID, tabManager: entry.tabManager, core: coreContext)
        Self.logger.info("Registered sceneID=\(sceneID, privacy: .public) windowID=\(windowID.value.uuidString, privacy: .public)")
    }
    /// Unregister a scene/window.
    public func unregisterScene(sceneID: String) {
        guard let entry, entry.sceneID == sceneID else { return }
        self.entry = nil
        appLifecycle.unregisterScene(sceneID: sceneID)
        windowRegistry.onSceneDisconnect(windowID: entry.windowID.value)
        Self.logger.info("Unregistered sceneID=\(sceneID, privacy: .public)")
    }
    // MARK: - AppLifecycle
    public func handleAppEvent(_ event: AppLifecycleEvent) {
        switch event {
        case .launch:
            Self.logger.debug("App launch")
        case .background:
            Self.logger.debug("App background")
            persistAllSessionsBestEffort()
        case .terminate:
            Self.logger.debug("App terminate")
            persistAllSessionsBestEffort()
            shutdownAllRuntimesBestEffort()
        }
    }
    // MARK: - WindowLifecycle
    public func handleWindowEvent(
        sceneID: String,
        event: WindowLifecycleEvent
    ) {
        guard let entry, entry.sceneID == sceneID else {
            Self.logger.debug("Ignoring window event; unknown sceneID=\(sceneID, privacy: .public)")
            return
        }
        Task {
            await PolicyCenter.shared.noteSceneEvent("window.\(event)", context: entry.coreContext)
        }
        switch event {
        case .connect:
            // No-op: registration should happen before connect is signalled.
            Self.logger.debug("Scene connect sceneID=\(sceneID, privacy: .public)")
            entry.coreContext.setActivationState(.connected)
        case .foreground:
            entry.viewModel.setSceneIsActive(true)
            entry.coreContext.setActivationState(.foreground)
            EngineController.shared.restoreAfterForeground(context: entry.coreContext)
            // Activate only once the UI root is on-screen.
            if entry.didRootViewAppear {
                entry.tabManager.endSessionRestoreAndActivateVisiblePanesIfNeeded()
            }
        case .background:
            entry.viewModel.setSceneIsActive(false)
            entry.coreContext.setActivationState(.background)
            EngineController.shared.prepareForBackground(context: entry.coreContext)
            entry.session.persistSessionNow()
            shutdownRuntimeBestEffort(entry)
        case .disconnect:
            // Last-chance save + full teardown.
            entry.session.persistSessionNow()
            entry.coreContext.setActivationState(.disconnected)
            teardownSceneBestEffort(entry)
            unregisterScene(sceneID: sceneID)
            return
        }
    }
    // MARK: - BrowserRuntime (internal callers)
    /// Public entrypoint for app layer (e.g. AppRootView) to replay lifecycle events
    /// without depending on internal view model types.
    public func handleBrowserRuntimeEvent(
        _ event: BrowserRuntimeEvent,
        session: BrowserSceneSession
    ) {
        handleBrowserRuntimeEvent(event, viewModel: session.viewModel)
    }
    /// Internal hook for SafariLikeKit UI/runtime layers.
    ///
    /// This avoids UI calling TabManager lifecycle methods directly.
    func handleBrowserRuntimeEvent(
        _ event: BrowserRuntimeEvent,
        viewModel: SplitBrowserViewModel
    ) {
        guard var entry, ObjectIdentifier(entry.viewModel) == ObjectIdentifier(viewModel) else {
            Self.logger.error("🚨 Ignoring runtime event (unregistered view model). event=\(String(describing: event), privacy: .public)")
            return
        }
        let sceneID = entry.sceneID
        Task {
            await PolicyCenter.shared.noteSceneEvent("runtime.\(event)", context: entry.coreContext)
        }

        // Map UI/runtime signals into CoreKit-owned lifecycle intents.
        let activeTabCandidate: UUID? = entry.tabManager.activeTabID ?? entry.tabManager.currentSessionStore.selectedTabID
        let effects: [SafariLikeCoreKit.TabPageLifecycleStateMachine.Effect] = {
            switch event {
            case .rootViewAppeared:
                return entry.coreContext.handleTabPageLifecycleEvent(.rootViewAppeared(activeTabID: activeTabCandidate))
            case .tabActivated(let tabID):
                return entry.coreContext.handleTabPageLifecycleEvent(.tabActivated(tabID: tabID))
            case .tabSuspended(let tabID):
                return entry.coreContext.handleTabPageLifecycleEvent(.tabSuspended(tabID: tabID))
            case .webViewAttached(let tabID):
                return entry.coreContext.handleTabPageLifecycleEvent(.webViewAttached(tabID: tabID))
            case .webViewDetached(let tabID):
                return entry.coreContext.handleTabPageLifecycleEvent(.webViewDetached(tabID: tabID))
            }
        }()
        CoreKitLifecycleEffectApplier.apply(effects, manager: entry.tabManager)

        switch event {
        case .rootViewAppeared:
            // UI-first restore: activate WKWebViews only after root UI is on-screen,
            // AND only when the owning scene is active/foreground.
            entry.didRootViewAppear = true
            if entry.viewModel.isSceneActive {
                entry.tabManager.endSessionRestoreAndActivateVisiblePanesIfNeeded()
            }
            appLifecycle.handleBrowserRuntimeEvent(
                sceneID: sceneID,
                event: event,
                viewModel: viewModel,
                tabManager: entry.tabManager
            )
        case .tabActivated:
            appLifecycle.handleBrowserRuntimeEvent(
                sceneID: sceneID,
                event: event,
                viewModel: viewModel,
                tabManager: entry.tabManager
            )
        case .tabSuspended:
            appLifecycle.handleBrowserRuntimeEvent(
                sceneID: sceneID,
                event: event,
                viewModel: viewModel,
                tabManager: entry.tabManager
            )
        case .webViewAttached:
            appLifecycle.handleBrowserRuntimeEvent(
                sceneID: sceneID,
                event: event,
                viewModel: viewModel,
                tabManager: entry.tabManager
            )
        case .webViewDetached:
            appLifecycle.handleBrowserRuntimeEvent(
                sceneID: sceneID,
                event: event,
                viewModel: viewModel,
                tabManager: entry.tabManager
            )
        }
        self.entry = entry
    }
    public func reconcileAttachmentState(sceneID: String, tabID: UUID, reason: String = "") {
        guard let entry, entry.sceneID == sceneID else { return }
        let snapshotReady: Bool = entry.viewModel.webViewRealityIfAlive(tabID: tabID)?.isRealityReady ?? false
        if snapshotReady,
           let status = appLifecycle.attachmentStatus(sceneID: sceneID),
           status.tabID == tabID,
           case .timedOut = status.state {
            Self.logger.fault(
                "🚨 INVARIANT VIOLATION: reconcile requested while realityReady=true but attachmentState=timedOut. sceneID=\(sceneID, privacy: .public) tabID=\(tabID.uuidString, privacy: .public) reason=\(reason, privacy: .public)"
            )
            #if DEBUG
            preconditionFailure("Invariant violated: realityReady=true must not be timedOut")
            #endif
        }
        appLifecycle.requestReconcile(sceneID: sceneID, tabID: tabID, viewModel: entry.viewModel, tabManager: entry.tabManager, reason: reason)
    }
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    // MARK: - Helpers
    private func persistAllSessionsBestEffort() {
        entry?.session.persistSessionNow()
    }
    private func shutdownAllRuntimesBestEffort() {
        if let entry {
            shutdownRuntimeBestEffort(entry)
        }
    }
    private func shutdownRuntimeBestEffort(_ entry: SceneEntry) {
        Task {
            // Ensure plugins get a proper unload path before TabManager drops the host.
            await entry.tabManager.pluginHost?.shutdown()
            await entry.tabManager.shutdown()
        }
    }
    private func teardownSceneBestEffort(_ entry: SceneEntry) {
        // Ensure plugins unload even if the session invalidation path is taken.
        Task {
            await entry.tabManager.pluginHost?.shutdown()
        }
        entry.session.invalidateSession()
    }
}
