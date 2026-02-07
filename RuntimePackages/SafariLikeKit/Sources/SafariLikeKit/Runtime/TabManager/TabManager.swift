import Foundation
import SafariLikeCoreKit
import Combine
import CoreGraphics
import WebKit
import os
// BUILD-PERF-AUDIT(2026-01-21): Compile hotspot (core runtime coordinator + high fan-out).
// Prefer extracting narrow protocols into smaller files/modules; avoid adding imports unless necessary.
@MainActor
final class TabManager: ObservableObject, BrowserTabManaging {
    // MARK: - Controllers
    private lazy var activationController = TabActivationController(manager: self)
    private lazy var attachmentController = TabAttachmentController(manager: self)
    private lazy var restoreController = TabRestoreController(manager: self)
    private lazy var budgetController = TabBudgetController(manager: self)
    private lazy var sessionSyncController = TabSessionSyncController(manager: self)
    private lazy var pluginController = TabPluginController(manager: self)
    private lazy var engineObserverController = TabEngineObserverController(manager: self)

    // MARK: - Active Tab Binding Transactions
    /// Starts a new logical binding transaction.
    /// Any in-flight bind task that does not match the returned id must not commit.
    func beginBindingTransaction(reason: String, targetTabID: UUID) -> UInt64 {
        activationController.beginBindingTransaction(reason: reason, targetTabID: targetTabID)
    }

    func isCurrentBindingTransaction(_ tx: UInt64) -> Bool {
        activationController.isCurrentBindingTransaction(tx)
    }

    func logBindingRace(kind: String, tx: UInt64, tabID: UUID, context: String) {
        activationController.logBindingRace(kind: kind, tx: tx, tabID: tabID, context: context)
    }

    // MARK: - WebView Transition Tokens (Single Writer)
    /// Monotonic per-tab generation token for WKWebView activation/deactivation transitions.
    /// Any async completion (activation, load, readiness callbacks) must validate the token
    /// before committing side effects.
    func beginWebViewTransition(reason: String, tabID: UUID) -> UInt64 {
        attachmentController.beginWebViewTransition(reason: reason, tabID: tabID)
    }

    func isCurrentWebViewTransition(tabID: UUID, token: UInt64) -> Bool {
        attachmentController.isCurrentWebViewTransition(tabID: tabID, token: token)
    }
    let lifecycleTransitionTracing = TabLifecycleTransitionTracing()
    // MARK: - Resource Policy
    let tabResourcePolicy = SafariLikeCoreKit.TabResourcePolicy()
    // MARK: - Window Identity
    let windowID: String
    // MARK: - Layout Environment (UI-driven)
    /// High-level environment classification that drives runtime decisions.
    /// This is set by the UI layer (not by device idiom).
    var layoutEnvironment: LayoutEnvironment = .compactSinglePane {
        didSet {
            guard oldValue != layoutEnvironment else { return }
            lifecycleController.applyRenderBudget(reason: "layout.changed")
        }
    }
    /// True when the UI can present two panes at once and split intent is enabled.
    var isSplitPanePresentationActive: Bool {
        layoutEnvironment == .splitPane && isSplitViewEnabled
    }
    /// Number of visible browser panes that should be kept within the render budget.
    var visiblePaneCount: Int {
        isSplitPanePresentationActive ? 2 : 1
    }
    func currentVisiblePaneTabIDs() -> [UUID] {
        if isSplitPanePresentationActive {
            return [leftTabID, rightTabID].compactMap { $0 }
        }
        return (activeTabID ?? currentSessionStore.selectedTabID).map { [$0] } ?? []
    }
    // MARK: - Pane-aware ownership
    var tabPaneAssignments: [UUID: PaneID] = [:]
    // MARK: - Restoration
    /// When true, we avoid eager WKWebView activation/loading so the UI can
    /// render first during session restore.
    var isPerformingSessionRestore: Bool = true
    var hasActivatedInitialVisiblePanes: Bool = false
    /// Tabs eligible for heuristics-driven prewarm after Phase A completes.
    /// Drained when visible panes activate.
    var pendingHeuristicsPrewarmTabIDs: [UUID] = []
    // MARK: - Components
    lazy var discardController: DiscardController = DiscardController(tabManager: self)
    /// Owns tab-scoped async tasks so they can be cancelled deterministically when:
    /// - tab closes
    /// - tab is discarded
    /// - pane/visibility changes (2-view budget)
    lazy var tabTasks: TabTaskRegistry = TabTaskRegistry()
    /// Placeholder components for an upcoming refactor. These are intentionally
    /// not used yet to preserve current behavior.
    lazy var restoreCoordinator: TabRestoreCoordinator = TabRestoreCoordinator(tabManager: self)
    lazy var runtimeRegistry: TabRuntimeFactory = TabRuntimeFactory(tabManager: self)
    lazy var paneCoordinator: PaneCoordinator = PaneCoordinator(tabManager: self)
    // MARK: - Pure State
    @Published private(set) var state: TabManagerState
    func mutateState(_ mutation: (inout TabManagerState) -> Void) {
        var copy = state
        mutation(&copy)
        state = copy
    }
    // MARK: - Binding State
    enum ActiveBindingState: Equatable {
        case unbound
        case binding(UUID)
        case bound(UUID)
        case unbinding(UUID)
    }
    @Published var activeBindingState: ActiveBindingState = .unbound
    // MARK: - Session Stores & Registries
    // Source of truth for tabs
    var currentSessionStore: BrowserSessionStore
    let normalSessionStore: BrowserSessionStore
    let privateSessionStore: BrowserSessionStore
    // IMPORTANT:
    // Keep the registry as a concrete type from SafariLikeCoreKit rather than an
    // existential (any WebViewProviding). In practice, the existential indirection
    // here has been a repeat offender for hard-to-repro EXC_BAD_ACCESS crashes
    // when Combine/KVO events re-enter the call stack.
    let normalTabRegistry: SafariLikeCoreKit.TabRegistry
    let privateTabRegistry: SafariLikeCoreKit.TabRegistry
    var currentTabRegistry: SafariLikeCoreKit.TabRegistry
    let normalPaneContexts: [PaneID: PaneContext]
    let privatePaneContexts: [PaneID: PaneContext]
    var currentPaneContexts: [PaneID: PaneContext] {
        isPrivateMode ? privatePaneContexts : normalPaneContexts
    }
    // MARK: - Dependencies
    let defaultHomeURLString: String
    private let historyStore: HistoryStore
    private let bookmarkStore: BookmarkStore
    let downloadStore: any DownloadProviding
    // MARK: - Scene Runtime Context (injected)
    private weak var runtimeContext: SceneRuntimeContext?
    func setRuntimeContext(_ context: SceneRuntimeContext) {
        self.runtimeContext = context
    }

    /// Narrow accessor for internal collaborators (controllers) that must remain nil-tolerant.
    var runtimeContextIfAvailable: SceneRuntimeContext? {
        runtimeContext
    }
    func requireRuntimeContext(
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) -> SceneRuntimeContext? {
        guard let context = runtimeContext else {
            #if DEBUG
            preconditionFailure("[TabManager] Missing SceneRuntimeContext. Ensure the scene is registered before runtime events. at \(fileID):\(line)")
            #else
            Diagnostics.logError(
                "[TabManager] Missing SceneRuntimeContext. Ensure the scene is registered before runtime events.",
                subsystem: .runtime,
                category: "SceneIsolation"
            )
            return nil
            #endif
        }
        return context
    }
    // MARK: - Mode
    var isPrivateMode: Bool {
        get { state.isPrivateMode }
        set {
            guard state.isPrivateMode != newValue else { return }
            mutateState { $0.isPrivateMode = newValue }
            modeSwitchTask?.cancel()
            modeSwitchTask = Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.lifecycleController.unbindActiveStore(cancelBindTask: true)
                self.currentTabRegistry = self.isPrivateMode ? self.privateTabRegistry : self.normalTabRegistry
                self.currentSessionStore = self.isPrivateMode ? self.privateSessionStore : self.normalSessionStore
                self.installSessionSubscriptions()
                if self.isSplitViewEnabled { self.disableSplitView() }
                self.lifecycleController.rebuildTabsFromSessionAndEnsureSelection()
            }
        }
    }
    // MARK: - Active & Split
    var activePane: ActivePane {
        get { state.splitViewState.activePane }
        set {
            guard state.splitViewState.activePane != newValue else { return }
            mutateState { $0.splitViewState.activePane = newValue }
            lifecycleController.applyRenderBudget(reason: "pane.changed")
        }
    }
    var isSplitViewEnabled: Bool {
        get { state.splitViewState.isEnabled }
        set {
            guard state.splitViewState.isEnabled != newValue else { return }
            mutateState { $0.splitViewState.isEnabled = newValue }
            lifecycleController.applyRenderBudget(reason: "split.changed")
        }
    }
    var leftTabID: UUID? {
        get { state.splitViewState.leftTabID }
        set { mutateState { $0.splitViewState.leftTabID = newValue } }
    }
    var rightTabID: UUID? {
        get { state.splitViewState.rightTabID }
        set { mutateState { $0.splitViewState.rightTabID = newValue } }
    }
    var splitViewRatio: CGFloat {
        get { state.splitViewState.ratio }
        set { mutateState { $0.splitViewState.ratio = newValue } }
    }
    // MARK: - Centralized Tab State
    var tabs: [TabState] {
        get { state.tabs }
        set { mutateState { $0.tabs = newValue } }
    }
    var activeTabID: UUID? {
        get { state.activeTabID }
        set { mutateState { $0.activeTabID = newValue } }
    }
    @Published var pageTitle: String?
    @Published var currentURL: URL?
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var estimatedProgress: Double = 0.0
    @Published var isLoading: Bool = false
    // MARK: - Combine
    var sessionCancellables = Set<AnyCancellable>()
    // MARK: - Callbacks back to VM
    var onNavStateChange: ((Bool, Bool, Bool, Double) -> Void)?
    var onAddressShouldSync: ((String) -> Void)?
    var onSessionAutosaveRequested: ((String) -> Void)?
    var onCompanionItemsUpdate: (([SafariLikeCoreKit.CompanionItem]) -> Void)?
    var onWebInputFocused: (() -> Void)?
    var onJournalEvent: ((SessionJournalEvent) -> Void)?

    /// UI policy hook: active selection changed.
    ///
    /// ViewModels should recompute any stored Decisions from snapshots in response.
    var onActiveTabChanged: ((UUID) -> Void)?
    // MARK: - Plugin Host
    let enablementStore: PluginEnablementStore
    private(set) var pluginHost: PluginHost?
    /// Window-scoped plugin session provider backing PluginContext APIs.
    ///
    /// This is created lazily so it can safely capture `self`.
    lazy var pluginSessionProvider: WindowPluginSessionProvider = {
        WindowPluginSessionProvider(
            tabManager: self,
            historyStore: self.historyStore,
            bookmarkStore: self.bookmarkStore
        )
    }()
    /// Optional back-reference to the window's NavigationService.
    /// Kept `weak` to avoid retain cycles (NavigationService holds TabManager weakly too).
    weak var navigationService: NavigationService?

    // MARK: - Narrow mutation helpers (Controllers)
    func setPluginHost(_ host: PluginHost?) {
        self.pluginHost = host
    }
    // MARK: - Async Tasks
    private var modeSwitchTask: Task<Void, Never>?
    var pluginHostTask: Task<Void, Never>?
    // MARK: - Lifecycle Controller
    lazy var lifecycleController = TabLifecycleController(manager: self)
    // MARK: - Tab Coordinator
    lazy var tabCoordinator: TabCoordinator = {
        TabCoordinator(manager: self)
    }()
    // MARK: - Tab Runtime Cache
    // Accessed by `TabRuntimeFactory`.
    var normalRuntimes: [TabRuntimeKey: TabRuntime] = [:]
    var privateRuntimes: [TabRuntimeKey: TabRuntime] = [:]
    // MARK: - Snapshots
    lazy var snapshotService: SnapshotService = {
        let service = SnapshotService()
        service.onSnapshotUpdated = { [weak self] tabID, data in
            guard let self else { return }
            self.updateSnapshotData(tabID: tabID, data: data)
        }
        return service
    }()

    func invalidateSnapshot(tabID: UUID, reason: String) {
        snapshotService.removeSnapshot(tabID: tabID)
        clearSnapshotData(tabID: tabID)
        _ = reason
    }
    // MARK: - Render Controllers (per-tab)
    private var renderControllers: [UUID: TabRenderController] = [:]
    func renderController(for tabID: UUID) -> TabRenderController {
        if let existing = renderControllers[tabID] { return existing }
        let created = TabRenderController(tabID: tabID, manager: self)
        renderControllers[tabID] = created
        return created
    }
    func removeRenderController(tabID: UUID) {
        renderControllers.removeValue(forKey: tabID)
    }
    // MARK: - Init
    init(
        normalSessionStore: BrowserSessionStore,
        privateSessionStore: BrowserSessionStore,
        normalTabRegistry: SafariLikeCoreKit.TabRegistry,
        privateTabRegistry: SafariLikeCoreKit.TabRegistry,
        normalPaneContexts: [PaneID: PaneContext],
        privatePaneContexts: [PaneID: PaneContext],
        defaultHomeURLString: String,
        historyStore: HistoryStore,
        bookmarkStore: BookmarkStore,
        downloadStore: any DownloadProviding,
        initialActiveTabID: UUID,
        windowID: String
    ) {
        self.windowID = windowID
        self.state = TabManagerState(
            tabs: [],
            activeTabID: initialActiveTabID,
            splitViewState: .init(),
            isPrivateMode: false,
            tabGroups: []
        )
        self.normalSessionStore = normalSessionStore
        self.privateSessionStore = privateSessionStore
        self.normalTabRegistry = normalTabRegistry
        self.privateTabRegistry = privateTabRegistry
        self.currentTabRegistry = normalTabRegistry
        self.normalPaneContexts = normalPaneContexts
        self.privatePaneContexts = privatePaneContexts
        self.currentSessionStore = normalSessionStore
        self.defaultHomeURLString = defaultHomeURLString
        self.historyStore = historyStore
        self.bookmarkStore = bookmarkStore
        self.downloadStore = downloadStore
        self.enablementStore = PluginEnablementStore(windowID: windowID)
        engineObserverController.startObserving(initialActiveTabID: initialActiveTabID)
        // Resource plugins are applied at WKWebViewConfiguration creation time
        // via WebContextManager's per-window configuration customizer.
        // Force-create scaffolding components now (no behavior change; they are unused).
        _ = restoreCoordinator
        _ = runtimeRegistry
        _ = paneCoordinator
        installSessionSubscriptions()
        // UI-first restore: do not activate/load WKWebView during init.
        // Active tab binding is triggered lazily when the SwiftUI view appears.
        discardController.start()
        // Initialize PluginHost and load enablement state/plugins asynchronously.
        pluginController.start(initialActiveTabID: initialActiveTabID)
    }
    // MARK: - BrowserTabManaging (Plugins)
    func enablePlugin(id: String) async {
        await pluginController.enablePlugin(id: id)
    }
    func disablePlugin(id: String) async {
        await pluginController.disablePlugin(id: id)
    }
    // MARK: - Lifecycle
    /// Explicit async shutdown pipeline for lifecycle management.
    @MainActor
    public func shutdown() async {
        // Unbind and set state to unbound
        tabCoordinator.unbindActiveStore(cancelBindTask: true)
        activeBindingState = .unbound
        discardController.stop()

        snapshotService.onSnapshotUpdated = nil
        snapshotService.clearAll()
        clearAllSnapshotData()

        // Async shutdown for registry cleanup
        await currentTabRegistry.shutdown()
        // Cancel plugin host and mode switch tasks
        await pluginController.shutdown()
        modeSwitchTask?.cancel()
        modeSwitchTask = nil
        // Remove all Combine subscriptions
        sessionCancellables.removeAll()
        // Nil out heavy references
        await engineObserverController.stopObserving()
    }
    deinit {
        // `deinit` is nonisolated; avoid touching actor-isolated state.
        // Cleanup is handled by explicit shutdown() and by TabCoordinator's own deinit.
        sessionCancellables.removeAll()
        modeSwitchTask?.cancel()
        pluginHostTask?.cancel()
    }
    private func updateSnapshotData(tabID: UUID, data: Data) {
        mutateState { state in
            guard let idx = state.tabs.firstIndex(where: { $0.id == tabID }) else { return }
            state.tabs[idx].snapshotData = data
            state.tabs[idx].hasSnapshot = true
            state.tabs[idx].lastSnapshotAt = Date()
        }
        lifecycleTransitionTracing.markSnapshotApplied(tabID: tabID)
    }

    private func clearSnapshotData(tabID: UUID) {
        mutateState { state in
            guard let idx = state.tabs.firstIndex(where: { $0.id == tabID }) else { return }
            state.tabs[idx].snapshotData = nil
            state.tabs[idx].hasSnapshot = false
            state.tabs[idx].lastSnapshotAt = nil
        }
    }

    private func clearAllSnapshotData() {
        mutateState { state in
            for idx in state.tabs.indices {
                state.tabs[idx].snapshotData = nil
                state.tabs[idx].hasSnapshot = false
                state.tabs[idx].lastSnapshotAt = nil
            }
        }
    }
    // MARK: - Memory Pressure
    func handleMemoryPressureEvent(_ event: EngineController.MemoryPressureEvent) {
        engineObserverController.handleMemoryPressureEvent(event)
    }
}
@MainActor
extension TabManager {
    // MARK: - Session Store
    var sessionStore: BrowserSessionStore {
        currentSessionStore
    }
    // MARK: - Download Store Accessors
    func makeDownloadDestinationURL(for filename: String) -> URL {
        downloadStore.makeDestinationURL(for: filename)
    }
    func refreshDownloads() {
        downloadStore.refresh()
    }
    func setLastDownloadErrorMessage(_ message: String) {
        downloadStore.lastErrorMessage = message
    }
    // MARK: - Tabs (Create/Delete)
    // MARK: - Tab Group Management
    func createTabGroup(_ name: String, color: BrowserTabGroup.TabGroupColor? = nil) {
        withCurrentSessionStore { store in
            _ = store.createTabGroup(name: name, color: color ?? .blue)
        }
    }
    func selectTabGroup(_ id: UUID) {
        withCurrentSessionStore { store in
            store.selectTabGroup(id: id)
        }
    }
    func deleteTabGroup(_ id: UUID) {
        withCurrentSessionStore { store in
            store.deleteTabGroup(id: id)
        }
    }
    func updateTabGroup(_ id: UUID, name: String, color: BrowserTabGroup.TabGroupColor? = nil) {
        withCurrentSessionStore { store in
            store.updateTabGroup(id: id, name: name, color: color)
        }
    }
    func addTabToGroup(_ tabID: UUID, groupID: UUID) {
        withCurrentSessionStore { store in
            store.addTabToGroup(tabID: tabID, groupID: groupID)
        }
    }
    // MARK: - Runtimes
    func runtime(for tabID: UUID, role: SafariLikeCoreKit.TabWebStore.Role = .primary) -> TabRuntime? {
        runtimeRegistry.runtime(for: tabID, role: role)
    }
}
@MainActor
extension TabManager {
    // MARK: - Runtime Eviction
    func destroyRuntime(for tabID: UUID) {
        runtimeRegistry.destroyRuntime(for: tabID)
    }
    // MARK: - Memory Pressure
    /// Best-effort memory pressure handler.
    ///
    /// Strategy: keep visible/protected panes alive, discard everything else.
    func handleMemoryPressure(source: String? = nil) {
        handleMemoryPressure(level: .warning, source: source)
    }
    func handleMemoryPressure(level: SafariLikeCoreKit.TabResourcePolicy.MemoryPressureLevel, source: String? = nil) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.handleMemoryPressureAsync(level: level, source: source)
        }
    }
    private func handleMemoryPressureAsync(level: SafariLikeCoreKit.TabResourcePolicy.MemoryPressureLevel, source: String? = nil) async {
        // Always trim WebViews first (cheap and fast), preserving the active 1–2 pane tabs.
        let protected: Set<UUID> = Set(currentVisiblePaneTabIDs())
        // More aggressive on critical: drop pooled/idle instances too.
        let detachMode: SafariLikeCoreKit.TabRegistry.WebViewDetachMode = (level == .critical) ? .cold : .warm
        if isPrivateMode {
            privateTabRegistry.handleMemoryPressure(protectedTabIDs: protected, mode: detachMode)
            normalTabRegistry.handleMemoryPressure(protectedTabIDs: [], mode: detachMode)
        } else {
            normalTabRegistry.handleMemoryPressure(protectedTabIDs: protected, mode: detachMode)
            privateTabRegistry.handleMemoryPressure(protectedTabIDs: [], mode: detachMode)
        }
        switch level {
        case .none:
            break
        case .warning:
            discardController.apply(trigger: .memoryWarning(.warning))
        case .critical:
            discardController.apply(trigger: .memoryWarning(.critical))
            discardController.apply(trigger: .thermalState(.critical))
        @unknown default:
            break
        }
        if let source {
            recordLifecycleEvent("memoryPressure.\(source)")
        } else {
            recordLifecycleEvent("memoryPressure")
        }
    }
}
@MainActor
extension TabManager {
    // MARK: - Legacy API compatibility
    func toggleSplitView() {
        if isSplitViewEnabled {
            disableSplitView()
        } else {
            enableSplitView()
        }
    }
    func newTab(inGroup group: UUID? = nil, inBackground: Bool = false) -> UUID {
        newTab(inBackground: inBackground)
    }
}
@MainActor
extension TabManager {
    // MARK: - Logger
    static let logger = Logger(
        subsystem: "SafariLikeKit",
        category: "TabManager"
    )
    // MARK: - Runtime Metrics
    var aliveRuntimeTabIDs: [UUID] {
        tabs.map { $0.id }.filter { currentTabRegistry.existingStore(for: $0) != nil }
    }
    // MARK: - Diagnostics
    func recordLifecycleEvent(_ message: String) {
        guard DiagnosticsGate.isEnabled else { return }
        Diagnostics.logInfo(message, subsystem: .runtime, category: "TabLifecycle")
    }
    func recordWebViewWarning(_ message: String) {
        guard DiagnosticsGate.isEnabled else { return }
        Diagnostics.logInfo(message, subsystem: .web, category: "WebViewState")
    }
    func recordWebViewDebug(_ message: String) {
        guard DiagnosticsGate.isEnabled else { return }
        Diagnostics.logDebug(message, subsystem: .web, category: "WebViewState")
    }

    func recordRenderPolicyInfo(_ message: String) {
        guard DiagnosticsGate.isEnabled else { return }
        Diagnostics.logInfo(message, subsystem: .runtime, category: "RenderPolicy")
    }
    func recordWebViewError(_ message: String) {
        guard DiagnosticsGate.isEnabled else { return }
        Diagnostics.logError(message, subsystem: .web, category: "WebViewState")
    }
    func validateActiveWebViewState(context: String) {
        guard DiagnosticsGate.isEnabled else { return }
        guard isPerformingSessionRestore == false else { return }
        switch activeBindingState {
        case .bound(let tabID):
            guard sessionStore.tabs.contains(where: { $0.id == tabID }) else {
                recordWebViewError("Invalid bound tab (missing from session store). context=\(context)")
                return
            }
            guard let store = currentTabRegistry.existingStore(for: tabID) else {
                recordWebViewError("Bound tab has no live TabWebStore. context=\(context)")
                return
            }
            if store.webViewHandle == nil {
                recordWebViewWarning("Bound tab store missing webViewHandle. context=\(context)")
            }
        case .binding, .unbinding, .unbound:
            break
        }
    }
}

@MainActor
extension TabManager {
    // MARK: - Single-writer activation/deactivation API

    /// Detach/deactivate a tab's WKWebView through the registry, with idempotency + debug logging.
    func requestDeactivateWebView(
        tabID: UUID,
        mode: SafariLikeCoreKit.TabRegistry.WebViewDetachMode,
        reason: String
    ) {
        attachmentController.requestDeactivateWebView(tabID: tabID, mode: mode, reason: reason)
    }

    /// Activate a store via runtime with token gating. Returns nil when stale.
    func activateRuntimeStore(
        tabID: UUID,
        role: SafariLikeCoreKit.TabWebStore.Role = .primary,
        protectedTabIDs: Set<UUID>,
        token: UInt64,
        reason: String
    ) async -> SafariLikeCoreKit.TabWebStore? {
        return await attachmentController.activateRuntimeStore(
            tabID: tabID,
            role: role,
            protectedTabIDs: protectedTabIDs,
            token: token,
            reason: reason
        )
    }

    /// Runtime-owned helper used by UI-facing code paths to load a URL into a background tab.
    func loadURLStringInBackgroundTab(tabID: UUID, urlString: String, reason: String) {
        attachmentController.loadURLStringInBackgroundTab(tabID: tabID, urlString: urlString, reason: reason)
    }
}

@MainActor
extension TabManager {
    /// Single deterministic entrypoint for render budget + visibility decisions.
    ///
    /// - Computes the policy in one pure function (`RenderVisibilityPolicy.decide`).
    /// - Applies the result in one place (this method) using single-writer APIs.
    func reconcileRenderVisibilityPolicy(reason: String) {
        budgetController.reconcileRenderVisibilityPolicy(reason: reason)
    }
}
@MainActor
extension TabManager {
    /// Reorder tabs in the current session store.
    func moveTab(from: Int, to: Int) {
        currentSessionStore.moveTab(from: from, to: to)
    }
}
@MainActor
extension TabManager {
    /// The UI calls this as tab overview appears/disappears.
    ///
    /// Safari behavior: when overview is visible we freeze all webviews
    /// (render budget 0) to keep scrolling smooth.
    func setTabOverviewVisible(_ visible: Bool) {
        budgetController.setTabOverviewVisible(visible)
    }
}
@MainActor
extension TabManager {
    /// Handles WebKit "new window" requests (e.g. target=_blank) that have been
    /// routed through policy to the app layer.
    func openInNewTabFromPolicy(request: URLRequest) {
        activationController.openInNewTabFromPolicy(request: request)
    }
}
// BUILD-PERF-AUDIT(2026-01-21): Compile hotspot (restore path touches many runtime types).
// Keep dependencies narrow; keep debug-only helpers gated to reduce rebuild cost.
@MainActor
extension TabManager {
    // MARK: - Lifecycle State
    func setLifecycle(
        tabID: UUID,
        lifecycle: TabLifecycleState,
        runtimeAttachment: RuntimeAttachmentState
    ) {
        let previousLifecycle: TabLifecycleState? = state.tabs.first(where: { $0.id == tabID })?.lifecycle
        mutateState { state in
            guard let idx = state.tabs.firstIndex(where: { $0.id == tabID }) else { return }
            state.tabs[idx].lifecycle = lifecycle
            state.tabs[idx].runtimeAttachment = runtimeAttachment
        }
        // Lifecycle-owned cancellation: no tab-scoped async work may outlive discard/close.
        // Suspended tabs also should not keep pending activation/load work.
        switch lifecycle {
        case .discarded:
            tabTasks.cancelAll(for: tabID)
        case .closed:
            tabTasks.cancelAll(for: tabID, excluding: [.close])
        case .suspended:
            tabTasks.cancelTask(tabID: tabID, key: .ensureLoaded)
            tabTasks.cancelTask(tabID: tabID, key: .renderBudgetActivate)
            tabTasks.cancelTask(tabID: tabID, key: .splitCompanionActivate)
            tabTasks.cancelTask(tabID: tabID, key: .scrollRestore)
        default:
            break
        }
        if let from = previousLifecycle, from != lifecycle {
            let snapshotAlreadyApplied = (state.tabs.first(where: { $0.id == tabID })?.hasSnapshot ?? false)
            lifecycleTransitionTracing.beginIfNeeded(
                tabID: tabID,
                from: from,
                to: lifecycle,
                snapshotAlreadyApplied: snapshotAlreadyApplied
            )
            switch runtimeAttachment {
            case .attached:
                lifecycleTransitionTracing.markWebViewReady(tabID: tabID)
                markSessionRestorePhaseBFirstWebReadyIfNeeded(tabID: tabID)
                maybeEndSessionRestoreTraceIfSatisfied()
            case .detached:
                lifecycleTransitionTracing.markWebViewDetached(tabID: tabID)
            }
        }
        withCurrentSessionStore { store in
            store.updateTab(id: tabID, lifecycleState: lifecycle)
        }
    }
    // MARK: - Restoration
    func endSessionRestoreAndActivateVisiblePanesIfNeeded() {
        restoreController.endSessionRestoreAndActivateVisiblePanesIfNeeded()
    }

    func prewarmHeuristicsCandidatesIfNeeded() {
        budgetController.prewarmHeuristicsCandidatesIfNeeded()
    }

    func applyRestoredSplitTabIDs(_ ids: [UUID]) {
        restoreController.applyRestoredSplitTabIDs(ids)
    }

    func activateCompanionPaneIfNeeded(tabID: UUID) {
        attachmentController.activateCompanionPaneIfNeeded(tabID: tabID)
    }
    func snapshotDataForTabIfAvailable(_ tabID: UUID) -> Data? {
        state.tabs.first(where: { $0.id == tabID })?.snapshotData
    }
    // MARK: - Reader/Scroll Restoration
    func setReaderAvailability(tabID: UUID, isAvailable: Bool) {
        mutateState { state in
            guard let idx = state.tabs.firstIndex(where: { $0.id == tabID }) else { return }
            state.tabs[idx].reader.isReaderAvailable = isAvailable
            if isAvailable == false {
                state.tabs[idx].reader.isReaderEnabled = false
            }
        }
    }
    func setReaderEnabled(tabID: UUID, isEnabled: Bool) {
        mutateState { state in
            guard let idx = state.tabs.firstIndex(where: { $0.id == tabID }) else { return }
            // Only allow enabling if the page is considered readable.
            if isEnabled, state.tabs[idx].reader.isReaderAvailable == false { return }
            state.tabs[idx].reader.isReaderEnabled = isEnabled
        }
    }
    // MARK: - Session Restore Tracing (internal API)
    var isSessionRestoreInProgress: Bool { restoreController.isSessionRestoreInProgress }
    func isTabJSInteractive(_ tabID: UUID) -> Bool {
        restoreController.isTabJSInteractive(tabID)
    }
    func beginSessionRestoreTracingIfNeeded(sceneID: String) {
        restoreController.beginSessionRestoreTracingIfNeeded(sceneID: sceneID)
    }
    func markSessionRestorePhaseAUIReady(source: String) {
        restoreController.markSessionRestorePhaseAUIReady(source: source)
    }
    private func markSessionRestorePhaseBFirstWebReadyIfNeeded(tabID: UUID) {
        restoreController.markSessionRestorePhaseBFirstWebReadyIfNeeded(tabID: tabID)
    }
    func markSessionRestoreTabInteractive(tabID: UUID) {
        restoreController.markSessionRestoreTabInteractive(tabID: tabID)
    }
    func maybeEndSessionRestoreTraceIfSatisfied() {
        restoreController.maybeEndSessionRestoreTraceIfSatisfied()
    }
    // MARK: - Session Sync
    func installSessionSubscriptions() {
        sessionSyncController.installSessionSubscriptions()
    }
}
@MainActor
extension TabManager {
    // MARK: - Session Store Routing
    @inline(__always)
    func withCurrentSessionStore<T>(
        _ block: (BrowserSessionStore) -> T
    ) -> T {
        let store: BrowserSessionStore
        if isPrivateMode {
            store = privateSessionStore
        } else {
            store = normalSessionStore
        }
        return block(store)
    }
    // MARK: - Store Binding
    func unbindActiveStore(cancelBindTask: Bool = false) {
        tabCoordinator.unbindActiveStore(cancelBindTask: cancelBindTask)
    }
    // MARK: - Public Accessors
    /// The currently bound TabWebStore for the active tab, or nil if
    /// no tab is bound or binding is in progress.
    var activeStore: SafariLikeCoreKit.TabWebStore? {
        guard case let .bound(id) = activeBindingState else { return nil }
        return currentTabRegistry.existingStore(for: id)
    }
    /// Tab ID involved in the current binding lifecycle.
    ///
    /// NOTE: This is not pane-scoped; it reflects the TabCoordinator binding flow.
    var bindingTabID: UUID? {
        switch activeBindingState {
        case .unbound:
            return nil
        case let .binding(id), let .bound(id), let .unbinding(id):
            return id
        }
    }
    func runtimeStoreIfAlive(for tabID: UUID) -> SafariLikeCoreKit.TabWebStore? {
        return currentTabRegistry.existingStore(for: tabID)
    }
    // MARK: - Session Binding
    func bindSessionSelection(for store: BrowserSessionStore) {
        lifecycleController.bindSessionSelection(for: store)
    }
}
@MainActor
extension TabManager {
    // MARK: - Pane-aware ownership
    func paneID(for tabID: UUID) -> String {
        activationController.paneID(for: tabID)
    }
    func assignTab(_ tabID: UUID, to pane: PaneID) {
        activationController.assignTab(tabID, to: pane)
    }
    func removePaneAssignment(for tabID: UUID) {
        activationController.removePaneAssignment(for: tabID)
    }
    // MARK: - Selection
    func selectTab(_ id: UUID) {
        activationController.selectTab(id)
    }
    // MARK: - Tabs (Create/Delete)
    func newTab(inBackground: Bool = false) -> UUID {
        activationController.newTab(inBackground: inBackground)
    }
    /// Closes a tab, ensuring binding state is unbound before removal, and awaits registry cleanup.
    @MainActor
    func closeTabAsync(_ id: UUID) async {
        await activationController.closeTabAsync(id)
    }
    func closeTab(_ id: UUID) {
        activationController.closeTab(id)
    }
    func activateTab(_ id: UUID) {
        activationController.activateTab(id)
    }
    func forceAttachActiveTabWebView(reason: String) {
        attachmentController.forceAttachActiveTabWebView(reason: reason)
    }
    func selectLeftPane() {
        activationController.selectLeftPane()
    }
    func selectRightPane() {
        activationController.selectRightPane()
    }
    var leftPaneStore: SafariLikeCoreKit.TabWebStore? {
        guard let id = leftTabID else { return nil }
        return currentTabRegistry.existingStore(for: id)
    }
    var rightPaneStore: SafariLikeCoreKit.TabWebStore? {
        guard let id = rightTabID else { return nil }
        return currentTabRegistry.existingStore(for: id)
    }
}
@MainActor
extension TabManager {
    // MARK: - Split Pane
    enum ActivePane {
        case left
        case right
    }
    func enableSplitView() {
        lifecycleController.enableSplitView()
    }
    func disableSplitView() {
        lifecycleController.disableSplitView()
    }
}
