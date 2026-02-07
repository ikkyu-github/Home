import Foundation
import Combine
import SafariLikeCoreKit
/// Per-scene runtime isolation boundary.
///
/// Keyed by `UISceneSession.persistentIdentifier`.
/// Owns all per-scene mutable lifecycle/runtime state.
@MainActor
public final class SceneRuntimeContext: ObservableObject {
    internal let core: SafariLikeCoreKit.SceneRuntimeContext
    public let sceneID: SceneID
    /// Window identifier for this scene (used for WebContext scoping).
    public var windowID: String { core.windowID }

    /// Scene-local registry for associating a scene/window with its BrowserSceneSession.
    ///
    /// Must never be process-global.
    let sessionRegistry: BrowserSceneSessionRegistry
    /// Scene-local WebView ownership/activation registry (regular browsing profile).
    internal var tabRegistry: SafariLikeCoreKit.TabRegistry { core.tabRegistry }
    /// Scene-local WebView ownership/activation registry (private browsing profile).
    internal var privateTabRegistry: SafariLikeCoreKit.TabRegistry { core.privateTabRegistry }
    /// Scene-local `WKWebView` pool used by the regular profile registries.
    internal var webViewPool: WebViewPool { core.webViewPool }
    /// Scene-local `WKWebView` pool used by the private profile registries.
    internal var privateWebViewPool: WebViewPool { core.privateWebViewPool }
    /// Scene-local WebContext manager (must not be process-global).
    internal var webContextManager: WebContextManager { core.webContextManager }
    /// Scene-local WebContext router (delegates to app-wide heuristics store).
    internal var webContextRouter: WebContextRouter { core.webContextRouter }
    /// Per-window UI state that must not be shared across scenes.
    public let uiState: SceneUIState
    /// Debug overlay model (scene-scoped; avoids cross-scene leakage in multi-window).
    public let navigationPolicyOverlayModel: NavigationPolicyOverlayModel
    /// Debug overlay model (scene-scoped; avoids cross-scene leakage in multi-window).
    public let performanceOverlayModel: PerformanceOverlayModel
    private let runtimeTabRegistry = TabRuntimeRegistry()
    let watchdogController = WatchdogController()
    lazy var attachmentCoordinator: AttachmentCoordinator = {
        AttachmentCoordinator(
            watchdog: watchdogController,
            maxAttachedWebViews: max(core.tabRegistry.debugMaxConcurrentViewsLimit, core.privateTabRegistry.debugMaxConcurrentViewsLimit),
            statusSink: { [weak self] status in
                self?.applyAttachmentStatus(status)
            }
        )
    }()
    @Published private var attachmentStatus: WebViewAttachmentStatus? = nil
    #if DEBUG
    private var debugLastReconcileAtByTabID: [UUID: Date] = [:]
        public func debugLastReconcileAt(tabID: UUID) -> Date? {
            debugLastReconcileAtByTabID[tabID]
        }
    #endif
    init(sceneID: SceneID, tabManager: TabManager, core: SafariLikeCoreKit.SceneRuntimeContext) {
        self.core = core
        self.sceneID = sceneID
        self.sessionRegistry = BrowserSceneSessionRegistry()
        self.navigationPolicyOverlayModel = NavigationPolicyOverlayModel()
        self.performanceOverlayModel = PerformanceOverlayModel()
        // Per-window UI state lives here (not shared across scenes).
        // Persisting/mirroring into BrowserSessionStore is handled elsewhere.
        self.uiState = SceneUIState()
        // Allow runtime layers (e.g. TabManager) to update scene-scoped attachment state
        // without reaching for process-wide singletons.
        tabManager.setRuntimeContext(self)
    }
    /// Full teardown for scene disconnect.
    ///
    /// Requirements:
    /// - Must cancel timers/tasks.
    /// - Must release all WKWebViews (no lingering WebContexts).
    func shutdownAndReleaseWebViews() {
        attachmentCoordinator.shutdown()
        watchdogController.cancelAll()
        attachmentStatus = nil

        // CoreKit-owned teardown.
        core.shutdownAndReleaseWebViews()
        #if DEBUG
        debugLastReconcileAtByTabID.removeAll()
        #endif
    }
    func setAppIsActive(_ isActive: Bool) {
        attachmentCoordinator.setAppIsActive(isActive)
    }
    // MARK: - Attachment status (read-only)
    func currentAttachmentStatus() -> WebViewAttachmentStatus? {
        attachmentStatus
    }
    func attachmentStatusPublisher() -> AnyPublisher<WebViewAttachmentStatus?, Never> {
        $attachmentStatus
            .removeDuplicates(by: { lhs, rhs in
                Self.equivalentStatus(lhs, rhs)
            })
            .eraseToAnyPublisher()
    }
    private static func equivalentStatus(_ lhs: WebViewAttachmentStatus?, _ rhs: WebViewAttachmentStatus?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case (nil, _), (_, nil):
            return false
        case (let l?, let r?):
            guard l.tabID == r.tabID else { return false }
            return equivalentState(l.state, r.state)
        }
    }
    private static func equivalentState(_ lhs: WebViewAttachmentState, _ rhs: WebViewAttachmentState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.attaching, .attaching), (.ready, .ready), (.timedOut, .timedOut):
            return true
        case (.restoring, .restoring):
            // Restoring is a UX phase; snapshot bytes are not user-visible here.
            return true
        case (.failed(let lReason), .failed(let rReason)):
            return lReason == rReason
        default:
            return false
        }
    }
    private func applyAttachmentStatus(_ status: WebViewAttachmentStatus?) {
        // Avoid publishing changes during SwiftUI view updates (e.g. from UIViewRepresentable update callbacks).
        Task { @MainActor [weak self] in
            guard let self else { return }
            let previous = self.attachmentStatus
            if let previous, let status, previous.tabID == status.tabID, Self.equivalentState(previous.state, status.state) {
                return
            }
            self.attachmentStatus = status
        }
    }
    // MARK: - Runtime event routing
    func handleBrowserRuntimeEvent(
        _ event: LifecycleCoordinator.BrowserRuntimeEvent,
        viewModel: SplitBrowserViewModel,
        tabManager: TabManager
    ) {
        // UI is an event source only; CoreKit budget/lifecycle owns attachment decisions.
        tabManager.reconcileRenderVisibilityPolicy(reason: "lifecycle.\(event)")
        switch event {
        case .rootViewAppeared:
            if let tabID = viewModel.activeTabID {
                runtimeTabRegistry.setActiveTab(tabID)
            }
            guard let tabID = viewModel.activeTabID else { return }
            let requiresWebView = (core.tabPageLifecycleState(tabID: tabID) == .liveAttached)
            let io = makeAttachmentIO(tabID: tabID, viewModel: viewModel, tabManager: tabManager)
            if let store = viewModel.runtimeRealityObserverIfAlive(for: tabID) {
                attachmentCoordinator.startTrackingIfNeeded(tabID: tabID, store: store, io: io)
            }
            attachmentCoordinator.onRootViewAppeared(initialTabRequiresWebView: requiresWebView, io: io)
        case .tabActivated(let tabID):
            runtimeTabRegistry.setActiveTab(tabID)
            let requiresWebView = (core.tabPageLifecycleState(tabID: tabID) == .liveAttached)
            let io = makeAttachmentIO(tabID: tabID, viewModel: viewModel, tabManager: tabManager)
            if let store = viewModel.runtimeRealityObserverIfAlive(for: tabID) {
                attachmentCoordinator.startTrackingIfNeeded(tabID: tabID, store: store, io: io)
            }
            attachmentCoordinator.onTabActivated(tabRequiresWebView: requiresWebView, io: io)
        case .tabSuspended:
            break
        case .webViewAttached(let tabID):
            let io = makeAttachmentIO(tabID: tabID, viewModel: viewModel, tabManager: tabManager)
            if let store = viewModel.runtimeRealityObserverIfAlive(for: tabID) {
                attachmentCoordinator.startTrackingIfNeeded(tabID: tabID, store: store, io: io)
            }

            // Safari-grade correctness: attachment events must reflect runtime reality and
            // must not attach WKWebViews across windows/scenes.
            if let runtimeStore = viewModel.runtimeStoreIfAlive(for: tabID) {
                _ = TabLifecycleGuard.validateAttachmentEvent(store: runtimeStore, expectedWindowID: windowID)
            }
            attachmentCoordinator.onWebViewAttached(io: io)
        case .webViewDetached(let tabID):
            attachmentCoordinator.stopTracking(tabID: tabID)
            let requiresWebView = (core.tabPageLifecycleState(tabID: tabID) == .liveAttached)
            let io = makeAttachmentIO(tabID: tabID, viewModel: viewModel, tabManager: tabManager)
            attachmentCoordinator.onWebViewDetached(tabRequiresWebView: requiresWebView, io: io)
        }
    }
    func requestReconcile(tabID: UUID, viewModel: SplitBrowserViewModel, tabManager: TabManager, reason: String) {
        #if DEBUG
        debugLastReconcileAtByTabID[tabID] = Date()
        #endif
        let io = makeAttachmentIO(tabID: tabID, viewModel: viewModel, tabManager: tabManager)
        attachmentCoordinator.requestReconcile(tabID: tabID, io: io, reason: reason)
    }
    private func makeAttachmentIO(tabID: UUID, viewModel: SplitBrowserViewModel, tabManager: TabManager) -> AttachmentCoordinator.IO {
        let coreContext = core
        #if DEBUG
        return AttachmentCoordinator.IO(
            tabID: tabID,
            snapshotDataForRestoreUX: { [weak tabManager] in
                tabManager?.snapshotDataForTabIfAvailable(tabID)
            },
            hasWebViewHandle: { [weak viewModel] in
                viewModel?.runtimeStoreIfAlive(for: tabID)?.webViewHandle != nil
            },
            requestRuntimeActivate: { [weak tabManager] in
                guard let tabManager, tabManager.state.isTabOverviewVisible == false else { return }
                // Guardrail: only CoreKit decides whether this tab should be live.
                guard coreContext.tabPageLifecycleState(tabID: tabID) == .liveAttached else { return }
                let webTx = tabManager.beginWebViewTransition(reason: "attachment.reconcile", tabID: tabID)
                _ = await tabManager.activateRuntimeStore(
                    tabID: tabID,
                    protectedTabIDs: [tabID],
                    token: webTx,
                    reason: "attachment.reconcile"
                )
            },
            requestUIRerender: { [weak viewModel] in
                viewModel?.requestUIRerender()
            },
            applyWebsitePreferencesForActiveHost: { [weak viewModel] in
                viewModel?.applyWebsitePreferencesForActiveHost()
            },
            recordWebViewAttachToReady: { [weak self] tabID, seconds in
                guard let self else { return }
                self.performanceOverlayModel.recordWebViewAttachToReady(tabID: tabID, seconds: seconds)
            }
        )
        #else
        return AttachmentCoordinator.IO(
            tabID: tabID,
            snapshotDataForRestoreUX: { [weak tabManager] in
                tabManager?.snapshotDataForTabIfAvailable(tabID)
            },
            hasWebViewHandle: { [weak viewModel] in
                viewModel?.runtimeStoreIfAlive(for: tabID)?.webViewHandle != nil
            },
            requestRuntimeActivate: { [weak tabManager] in
                guard let tabManager, tabManager.state.isTabOverviewVisible == false else { return }
                let webTx = tabManager.beginWebViewTransition(reason: "attachment.reconcile", tabID: tabID)
                _ = await tabManager.activateRuntimeStore(
                    tabID: tabID,
                    protectedTabIDs: [tabID],
                    token: webTx,
                    reason: "attachment.reconcile"
                )
            },
            requestUIRerender: { [weak viewModel] in
                viewModel?.requestUIRerender()
            },
            applyWebsitePreferencesForActiveHost: { [weak viewModel] in
                viewModel?.applyWebsitePreferencesForActiveHost()
            }
        )
        #endif
    }
}
