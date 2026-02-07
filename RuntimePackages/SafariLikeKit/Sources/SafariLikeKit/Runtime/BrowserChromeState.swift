import SwiftUI
import UIKit
import Combine
import SafariLikeCoreKit
import SafariLikeUXKit
import WebKit
import OSLog
import SafariLikeContracts
// BUILD-PERF-AUDIT(2026-01-21): Compile hotspot (large ObservableObject used across many SwiftUI views).
// Changes here tend to invalidate lots of downstream type-checking; keep edits small and imports tight.
// MARK: - ⚠️ Architecture Boundary: Thumbnail Adapter
// Uses ThumbnailChromeAdapter (ObservableObject adapter) to expose
// thumbnail state to SwiftUI via EnvironmentObject while delegating
// capture operations to the underlying ThumbnailCapturing store.
/// UI/UX state to make the app feel like Safari iPad.
/// Keeps "chrome" state (toolbars/panels) out of the browser session model.
@MainActor
final class BrowserChromeState: ObservableObject {
    enum SplitViewMode {
        case single
        case dual
    }
    // MARK: - State Groups (Safari UX)
    /// A) ChromeInteractionState
    /// - chromeHeight
    /// - chromeOffset
    /// - isURLFocused
    /// - scrollProgress
    ///
    /// B) PageLifecycleState
    /// - isLaunching
    /// - isLoading
    /// - webViewAttached
    ///
    /// IMPORTANT: ChromeInteractionState must NOT be reset/mutated/animated from PageLifecycleState.
    @MainActor
    final class ChromeInteractionState: ObservableObject {
        @Published var chromeHeight: CGFloat = 96
        var minChromeHeight: CGFloat = 44
        var maxChromeHeight: CGFloat = 96
        /// 0 = fully expanded, 1 = fully collapsed.
        @Published fileprivate(set) var scrollProgress: CGFloat = 0
        /// Vertical translation used by the chrome container (derived from scrollProgress).
        @Published fileprivate(set) var chromeOffset: CGFloat = 0
        /// Derived from the chrome state machine; owned by interaction layer.
        @Published fileprivate(set) var isURLFocused: Bool = false
    }
    @MainActor
    final class PageLifecycleState: ObservableObject {
        @Published fileprivate(set) var isLaunching: Bool = true
        @Published fileprivate(set) var isLoading: Bool = false
        @Published fileprivate(set) var webViewAttached: Bool = false
    }
    // MARK: - Logger
    private static let logger = Logger(subsystem: "SafariLikeKit", category: "BrowserChrome")
    // MARK: - Dependencies
    let downloads: any DownloadProviding
    let thumbnails: ThumbnailChromeAdapter
    // MARK: - Sheets / overlays
    @Published var isAppSettingsPresented: Bool = false
    @Published var isDownloadsPresented: Bool = false
    @Published var isFindBarPresented: Bool = false
    @Published var isTextSizePresented: Bool = false
    @Published var isWebsiteSettingsPresented: Bool = false
    @Published var isPrivacyReportPresented: Bool = false
    @Published var isWebsiteDataPresented: Bool = false
    // MARK: - State Buckets
    let interaction = ChromeInteractionState()
    let page = PageLifecycleState()
    private var nestedStateCancellables: Set<AnyCancellable> = []
    // MARK: - Backward-compatible accessors
    /// Prefer `interaction` in new call sites.
    var chromeHeight: CGFloat {
        get { interaction.chromeHeight }
        set { interaction.chromeHeight = newValue }
    }
    var minChromeHeight: CGFloat {
        get { interaction.minChromeHeight }
        set { interaction.minChromeHeight = newValue }
    }
    var maxChromeHeight: CGFloat {
        get { interaction.maxChromeHeight }
        set { interaction.maxChromeHeight = newValue }
    }
    var scrollProgress: CGFloat { interaction.scrollProgress }
    var chromeOffset: CGFloat { interaction.chromeOffset }
    // MARK: - Split View (pure layout intent)
    /// Structural layout intent controlled by explicit user action.
    /// Must not be coupled to omnibox focus or keyboard visibility.
    @Published var splitViewMode: SplitViewMode = .single
    // MARK: - Find
    @Published var findQuery: String = ""
    /// UI triggers for find actions (set by VM)
    var onFindNext: (() -> Void)?
    var onFindPrevious: (() -> Void)?
    // MARK: - Reader / Text size
    @Published var textScalePercent: Int = 100
    @Published var isReaderAvailable: Bool = false
    @Published var isReaderEnabled: Bool = false
    // MARK: - Chrome Style
    /// Current chrome style as resolved by the layout layer.
    /// Used to keep Safari-like behavior consistent across rotation/size changes.
    @Published var chromeStyle: BrowserChromeStyle = .phonePortraitSafari
    // MARK: - UX Policy
    /// Centralized UX tuning (gesture thresholds, collapse distances, etc).
    /// Resolved and injected by the layout layer.
    @Published var uxPolicy: UXPolicy = .default
    // MARK: - Chrome State Machine (single source of truth)
    private var machine = ChromeStateMachine()
    @Published private(set) var chromeSnapshot: ChromeSnapshot
    // Prevent re-entrancy (ObservableObject/Combine feedback loops).
    private var isDispatchingChrome: Bool = false
    private var pendingChromeEvent: ChromeStateMachine.Event?
    init(
        downloads: any DownloadProviding,
        thumbnails: ThumbnailChromeAdapter,
        viewModel: SplitBrowserViewModel
    ) {
        self.downloads = downloads
        self.thumbnails = thumbnails
        chromeSnapshot = machine.snapshot()
        // Forward nested state changes so views depending on BrowserChromeState update.
        interaction.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &nestedStateCancellables)
        page.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &nestedStateCancellables)
        updateChromeInteractionState()
        self.vm = viewModel
        attach()
    }
    // MARK: - Scroll Physics
    @Published private(set) var scrollDirection: ScrollDirection = .none
    @Published private(set) var scrollVelocity: CGFloat = 0
    @Published private(set) var isDragging: Bool = false
    @Published private(set) var isDecelerating: Bool = false
    /// Timestamp (CACurrentMediaTime) of the most recent scroll delta we treated as user intent.
    /// Used by DEBUG tooling to distinguish legitimate end-of-scroll snap from non-user jumps.
    @Published private(set) var lastScrollInteractionTime: CFTimeInterval = 0
    private var lastScrollOffset: CGPoint = .zero
    private var lastScrollTime: CFTimeInterval = 0
    private var scrollVelocitySamples: [CGFloat] = []
    private static let maxVelocitySamples = 3
    // MARK: - Tab Overview Capture Tuning
    private var overviewCaptureCooldown: CFTimeInterval { uxPolicy.tabOverview.thumbnailCaptureCooldownSeconds }
    private var isTabOverviewUserInteracting: Bool = false
    private var overviewBatchCaptureTask: Task<Void, Never>?
    private var overviewPerTabCaptureTasks: [UUID: Task<Void, Never>] = [:]
    enum ScrollDirection {
        case none, up, down
    }
    // MARK: - Internals
    private weak var vm: SplitBrowserViewModel?
    private weak var runtimeContext: SceneRuntimeContext?
    private weak var boundStore: SafariLikeCoreKit.TabWebStore?
    private var boundTabID: UUID?
    private var cancellables: Set<AnyCancellable> = []
    /// Returns true if chrome state is currently bound to an active tab.
    /// Use this to check if operations like thumbnail capture are safe.
    var isBound: Bool {
        boundTabID != nil
    }
    func attach(to viewModel: SplitBrowserViewModel) {
        self.vm = viewModel
        attach()
    }
    func attach(to viewModel: SplitBrowserViewModel, context: SceneRuntimeContext) {
        self.vm = viewModel
        self.runtimeContext = context
        attach()
    }
    // MARK: - Attach
    func attach() {
        guard let vm else { return }
        guard let runtimeContext else { return }
        cancellables.removeAll()
        // Page lifecycle mirrors (read-only for chrome interaction).
        // Single source of truth: SceneRuntimeContext for this window.
        runtimeContext
            .attachmentStatusPublisher()
            .receive(on: RunLoop.main)
            .sink { [weak self, weak vm] status in
                guard let self, let vm else { return }
                // Only treat as "attached" when the status refers to the active tab.
                guard let activeTabID = vm.activeTabID else {
                    if self.page.webViewAttached != false { self.page.webViewAttached = false }
                    if self.page.isLaunching != true { self.page.isLaunching = true }
                    return
                }
                // Tabs that don't require a WebView should never show launching.
                let requiresWebView: Bool = {
                    guard let tab = vm.sessionStore.tabs.first(where: { $0.id == activeTabID }) else { return true }
                    return WebViewRequirementPolicy.decide(tabState: tab.state).requiresWebView
                }()
                guard requiresWebView else {
                    if self.page.webViewAttached != true { self.page.webViewAttached = true }
                    if self.page.isLaunching != false { self.page.isLaunching = false }
                    return
                }
                let isActiveTabStatus = (status?.tabID == activeTabID)
                let attached: Bool = {
                    guard isActiveTabStatus else { return false }
                    guard let state = status?.state else { return false }
                    if case .ready = state { return true }
                    return false
                }()
                if self.page.webViewAttached != attached { self.page.webViewAttached = attached }
                let launching = (attached == false)
                if self.page.isLaunching != launching { self.page.isLaunching = launching }
            }
            .store(in: &cancellables)
        vm.$isLoading
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isLoading in
                guard let self else { return }
                self.page.isLoading = isLoading
            }
            .store(in: &cancellables)
        vm.tabManager.$activeBindingState
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .bound:
                    self.hookActiveTab()
                case .unbound, .binding, .unbinding:
                    self.unbindChrome()
                }
            }
            .store(in: &cancellables)
        vm.$state
            .map { $0.isTabOverviewVisible }
            .removeDuplicates()
            .sink { [weak self] (isVisible: Bool) in
                guard let self else { return }
                self.dispatchChrome(.overviewToggled(isVisible))
                if isVisible {
                    self.scheduleOverviewThumbnailsCapture()
                } else {
                    self.cancelPendingOverviewCaptures()
                    self.isTabOverviewUserInteracting = false
                }
            }
            .store(in: &cancellables)
        // Keep chrome-level reader UI in sync with active tab state.
        vm.tabManager.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                guard let activeID = state.activeTabID,
                      let tab = state.tabs.first(where: { $0.id == activeID })
                else {
                    self.isReaderAvailable = false
                    self.isReaderEnabled = false
                    return
                }
                self.isReaderAvailable = tab.reader.isReaderAvailable
                self.isReaderEnabled = tab.reader.isReaderEnabled
            }
            .store(in: &cancellables)
            updateChromeInteractionState()
    }
    // MARK: - Chrome Event API (UI calls these; machine stays internal)
    func setAddressFocused(_ focused: Bool) {
        if chromeSnapshot.state == .editing && focused {
            return
        }
        dispatchChrome(.focusChanged(focused))
        if focused {
            resetScrollTrackingBaseline()
        }
        if focused == false {
            // Keep VM focus mirror consistent when chrome dismisses focus.
            Task { @MainActor in
                self.vm?.bar.send(SafariLikeContracts.AddressBarEvent.focusChanged(isFocused: false))
            }
        }
    }
    func commitAddressEditing() {
        dispatchChrome(.commit)
        Task { @MainActor in
            self.vm?.bar.send(SafariLikeContracts.AddressBarEvent.focusChanged(isFocused: false))
        }
    }
    func cancelAddressEditing() {
        dispatchChrome(.cancel)
        Task { @MainActor in
            self.vm?.bar.send(SafariLikeContracts.AddressBarEvent.focusChanged(isFocused: false))
        }
    }
    func dismissOmniboxOverlay() {
        // Overlay is derived from editing state.
        setAddressFocused(false)
    }
    /// Unified scroll entry point for chrome reactions.
    /// Side effects (thumbnail capture, preferences) remain elsewhere.
    func handleWebScroll(contentOffset: CGPoint, scrollView: UIScrollView) {
        updateScrollPhysics(contentOffset: contentOffset, scrollView: scrollView)
    }
    func setChromeStyle(_ style: BrowserChromeStyle) {
        guard chromeStyle != style else { return }
        chromeStyle = style
        // Rotation/size changes can cause large contentOffset jumps; re-baseline so we don't
        // instantly collapse/expand from a stale delta.
        resetScrollTrackingBaseline()
        // Safari iPad landscape: do not keep any collapsed progress.
        if style == .padLandscapeSafari {
            resetScrollCollapse(animated: false)
        }
        // Safari iPad landscape: never remain in the collapsed state.
        if style == .padLandscapeSafari, chromeSnapshot.isCollapsed {
            dispatchChrome(.cancel)
        }
    }
    @MainActor
    private func dispatchChrome(_ event: ChromeStateMachine.Event) {
        if isDispatchingChrome {
            pendingChromeEvent = event
            return
        }
        isDispatchingChrome = true
        defer {
            isDispatchingChrome = false
            if let pending = pendingChromeEvent {
                pendingChromeEvent = nil
                Task { @MainActor in
                    self.dispatchChrome(pending)
                }
            }
        }
        let snapshot = machine.reduce(event)
        chromeSnapshot = snapshot
        applyChromeHeightFromSnapshot(snapshot, lastEvent: event)
    }
    private func applyChromeHeightFromSnapshot(_ snapshot: ChromeSnapshot, lastEvent: ChromeStateMachine.Event) {
        // Safari iPhone: chrome height/offset are continuously driven by scrollProgress.
        // Avoid fighting that pipeline on each `.scroll` event.
        if case .scroll = lastEvent {
            updateChromeInteractionState()
            return
        }
        // Safari-grade invariant:
        // Non-scroll events (focus, commit/cancel, overview toggles, tab binding/attaching)
        // must NOT mutate chrome geometry (height/offset/progress). Otherwise the chrome can
        // move by 1px due to non-user-driven state transitions.
        updateChromeInteractionState()
    }
    /// Public lifecycle hook for external owners (e.g. the ViewModel)
    /// to explicitly detach chrome from the current ViewModel and
    /// release subscriptions.
    ///
    /// Safe to call multiple times; subsequent calls become no-ops.
    func unbind() {
        cancelPendingOverviewCaptures()
        cancellables.removeAll()
        unbindChrome()
        vm = nil
    }
    // MARK: - Active Tab
    /// Bind the chrome state to the currently active tab's store.
    ///
    /// This method is the single entry point for (re)binding chrome state.
    /// All actual binding work is delegated to `bindChrome(to:tabID:)`.
    func hookActiveTab() {
        // Guard 1: VM must be alive
        guard let vm else {
            // VM deallocated - normal cleanup during deinit
            Self.logger.debug("Cannot hook active tab: VM deallocated")
            unbindChrome()
            return
        }
        // Guard 2: VM must have an active tab ID
        guard let tabID = vm.activeTabID else {
            // No active tab - normal during initialization or all tabs closed
            Self.logger.debug("Cannot hook active tab: no activeTabID set")
            unbindChrome()
            return
        }
        // Guard 3: Skip if already bound to this tab (no duplicate binding)
        guard boundTabID != tabID else {
            // Already bound to this tab, nothing to do
            return
        }
        // Guard 4: activeStore must exist (if activeTabID is set)
        guard let store = vm.activeStore else {
            // Race condition: tabID exists but store was deleted between checks
            Self.logger.error("activeStore is nil despite activeTabID being set (tabID: \(tabID.uuidString)). This indicates a race condition in TabManager.")
            unbindChrome()
            return
        }
        Self.logger.debug("Binding chrome state to tabID: \(tabID.uuidString)")
        bindChrome(to: store, tabID: tabID)
        Self.logger.debug("Successfully bound chrome state to tabID: \(tabID.uuidString)")
        // Safari UX requirement:
        // - Binding/attaching a WKWebView or switching tabs must NOT mutate the chrome's
        //   interaction-driven presentation (height/progress). That would cause non-user “jumps”.
        // - We only re-baseline scroll tracking here to avoid treating restore jumps as intent.
        resetScrollTrackingBaseline()
    }
    /// Perform the actual chrome binding to a specific TabWebStore.
    ///
    /// - Parameters:
    ///   - store: The TabWebStore representing the active tab
    ///   - tabID: The active tab identifier
    private func bindChrome(to store: SafariLikeCoreKit.TabWebStore, tabID: UUID) {
        // Establish binding invariant
        boundTabID = tabID
        boundStore = store
        // Install page finish callback. The callback is stored on the store instance itself,
        // so we do not need to weakly capture the store. Only [weak self] is needed.
        // The callback is retained by the store, so store does not need to be weak here.
        store.onPageDidFinish = { [weak self] (url: URL?, title: String) in
            guard let self else { return }
            self.handlePageDidFinish(for: tabID, store: store, url: url, title: title)
        }
        // Perform initial thumbnail capture for the newly bound tab.
        handleInitialThumbnailCapture(for: tabID, store: store)
        // Download failure side-effect remains a simple delegate into the downloads adapter.
        store.onDownloadDidFail = { [weak self] error in
            self?.downloads.failActiveDownload(error: error)
        }

        store.onNavigationFailure = { record in
            Task { @MainActor in
                NetworkDiagnosticsModel.shared.recordNavigationFailure(record)
            }
        }
        // Seed attachment state for the active tab.
        // IMPORTANT: Do NOT treat `webViewHandle != nil` as "attached". Real attachment is
        // reported by the SwiftUI container (UIViewRepresentable) when it actually adds the
        // WKWebView into the view hierarchy.
        if let vm = vm {
            runtimeContext?.handleBrowserRuntimeEvent(.tabActivated(tabID: tabID), viewModel: vm, tabManager: vm.tabManager)
        }
        // Also refresh reader availability immediately on tab switch.
        vm?.handleReaderPageDidFinish(tabID: tabID, store: store, url: store.state.currentURL)
    }
    /// Handle a single page-did-finish event for the bound chrome/tab pair.
    private func handlePageDidFinish(
        for tabID: UUID,
        store: SafariLikeCoreKit.TabWebStore,
        url: URL?,
        title: String
    ) {
        // Ensure chrome is still logically bound before handling the event.
        guard let boundTabID = boundTabID else {
            Self.logger.error("Lifecycle mismatch: pageDidFinish for tabID \(tabID.uuidString) while chrome has no boundTabID; ignoring event")
            return
        }
        // The incoming event must match the currently bound tab.
        guard boundTabID == tabID else {
            Self.logger.error("Lifecycle mismatch: pageDidFinish for tabID \(tabID.uuidString) but chrome is bound to tabID \(boundTabID.uuidString); ignoring event")
            return
        }
        guard let vm = vm else {
            Self.logger.error("Lifecycle mismatch: pageDidFinish for tabID \(tabID.uuidString) but view model has been deallocated; ignoring event")
            return
        }
        guard let webView = store.webViewHandle?.webView else { return }
        // IMPORTANT:
        // Do not treat navigation completion as an attachment/readiness signal.
        // Chrome "launching/attached" is derived from the scene's attachment status
        // (i.e. whether the WKWebView is actually renderable in the view hierarchy).
        if vm.isTabOverviewVisible {
            scheduleOverviewThumbnailCapture(tabID: tabID, webView: webView)
        } else if thumbnails.hasThumbnail(for: tabID) == false {
            thumbnails.capture(
                tabID: tabID,
                webView: webView,
                targetWidth: 520,
                minInterval: 0
            )
        }
        // Refresh reader availability and apply default (if enabled) after navigation completes.
        vm.handleReaderPageDidFinish(tabID: tabID, store: store, url: url)
    }
    /// Perform initial thumbnail capture for a newly bound tab, if needed.
    private func handleInitialThumbnailCapture(
        for tabID: UUID,
        store: SafariLikeCoreKit.TabWebStore
    ) {
        // Ensure chrome is still logically bound before capturing thumbnails.
        guard let boundTabID = boundTabID else {
            Self.logger.error("Lifecycle mismatch: initial thumbnail capture for tabID \(tabID.uuidString) while chrome has no boundTabID; ignoring")
            return
        }
        guard boundTabID == tabID else {
            Self.logger.error("Lifecycle mismatch: initial thumbnail capture for tabID \(tabID.uuidString) but chrome is bound to tabID \(boundTabID.uuidString); ignoring")
            return
        }
        guard thumbnails.hasThumbnail(for: tabID) == false else { return }
        guard let webView = store.webViewHandle?.webView else { return }
        thumbnails.capture(
            tabID: tabID,
            webView: webView,
            targetWidth: 520,
            minInterval: 0
        )
    }
    /// Unbind chrome state from current tab.
    /// 
    /// **When to call:**
    /// - Tab is being deleted
    /// - Mode is switching (private ↔ normal)
    /// - VM is deallocating
    /// 
    /// **Safety:**
    /// - Safe to call multiple times (idempotent)
    /// - Safe to call when not bound
    /// - Clears side effect callbacks
    private func unbindChrome() {
        guard isBound else {
            // Already unbound, nothing to do
            return
        }
        // Capture boundTabID before clearing it.
        // Invariant: if we're bound, a tabID must exist.
        guard let previousTabID = boundTabID else {
            assertionFailure("Invariant violated: isBound=true but boundTabID is nil")
            Self.logger.error("Lifecycle mismatch: unbindChrome called while boundTabID is nil; clearing bound store callbacks")
            boundTabID = nil
            if let store = boundStore {
                store.onPageDidFinish = nil
                store.onDownloadDidFail = nil
				store.onNavigationFailure = nil
            }
            boundStore = nil
            return
        }
        boundTabID = nil
        // Clear callbacks on the previously bound store to avoid retain cycles
        if let store = boundStore {
            store.onPageDidFinish = nil
            store.onDownloadDidFail = nil
			store.onNavigationFailure = nil
        }
        boundStore = nil
        // Log the unbinding with captured tabID
        let tabIDString = previousTabID.uuidString
        Self.logger.debug("Unbinding chrome state from tabID: \(tabIDString)")
        // Inform the view model that there is no longer a bound
        // web view for the active tab.
        if let vm = vm {
            runtimeContext?.handleBrowserRuntimeEvent(.webViewDetached(tabID: previousTabID), viewModel: vm, tabManager: vm.tabManager)
        }
    }
    // Removed unused optional activeStore() helper. Use vm.activeStore directly.
    private func captureOverviewThumbnailsBestEffort() {
        guard let vm else {
            Self.logger.error("captureOverviewThumbnailsBestEffort called but view model has been deallocated; skipping thumbnail capture")
            return
        }
        for tab in vm.tabs {
            guard let store = vm.runtimeStoreIfAlive(for: tab.id) else { continue }
            if let webView = store.webViewHandle?.webView {
                thumbnails.captureForOverviewIfNeeded(tabID: tab.id, webView: webView)
            }
        }
    }
    // MARK: - Tab Overview Capture Control
    /// Called by the tab overview UI to indicate scroll/drag interaction.
    /// While true, overview thumbnail capture will be deferred.
    func setTabOverviewUserInteracting(_ isInteracting: Bool) {
        isTabOverviewUserInteracting = isInteracting
        if isInteracting == false {
            scheduleOverviewThumbnailsCapture()
        }
    }
    /// Best-effort request to refresh overview thumbnails after a cooldown.
    func requestOverviewThumbnailsCapture() {
        scheduleOverviewThumbnailsCapture()
    }
    private func cancelPendingOverviewCaptures() {
        overviewBatchCaptureTask?.cancel()
        overviewBatchCaptureTask = nil
        for (_, task) in overviewPerTabCaptureTasks {
            task.cancel()
        }
        overviewPerTabCaptureTasks.removeAll()
    }
    private func shouldDeferOverviewCapture() -> Bool {
        // Avoid snapshotting WKWebView while scrolling/dragging to reduce jank.
        // Also avoid while the tab overview itself is being scrolled/dragged.
        isDragging || isDecelerating || isTabOverviewUserInteracting
    }
    private func scheduleOverviewThumbnailsCapture() {
        guard let vm, vm.isTabOverviewVisible else { return }
        overviewBatchCaptureTask?.cancel()
        overviewBatchCaptureTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.overviewCaptureCooldown * 1_000_000_000))
            guard Task.isCancelled == false else { return }
            guard self.shouldDeferOverviewCapture() == false else { return }
            self.captureOverviewThumbnailsBestEffort()
        }
    }
    private func scheduleOverviewThumbnailCapture(tabID: UUID, webView: WKWebView) {
        // Per-tab debounce so repeated page finishes don't spam captures while overview is visible.
        overviewPerTabCaptureTasks[tabID]?.cancel()
        overviewPerTabCaptureTasks[tabID] = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.overviewCaptureCooldown * 1_000_000_000))
            guard Task.isCancelled == false else { return }
            guard self.vm?.isTabOverviewVisible == true else { return }
            guard self.shouldDeferOverviewCapture() == false else { return }
            self.thumbnails.captureForOverviewIfNeeded(tabID: tabID, webView: webView)
        }
    }
    // MARK: - Reader / Text size
    func setTextScalePercent(_ percent: Int) {
        let clamped = max(50, min(200, percent))
        textScalePercent = clamped
        guard let vm = vm else {
            Self.logger.error("setTextScalePercent called but view model has been deallocated; skipping website preferences application")
            return
        }
        vm.applyWebsitePreferencesForActiveHost()
    }
    func toggleReaderMode() {
        guard let vm = vm else {
            Self.logger.error("toggleReaderMode called but view model has been deallocated; skipping")
            return
        }
        vm.toggleReaderMode()
    }
    // MARK: - Share
    func shareCurrentPage() {
        guard let vm else {
            Self.logger.error("Lifecycle mismatch: shareCurrentPage called but view model has been deallocated; aborting share flow")
            return
        }
        vm.shareCoordinator.shareCurrentPageLink(from: vm)
    }

    func shareCurrentPageAsPDF() {
        guard let vm else {
            Self.logger.error("Lifecycle mismatch: shareCurrentPageAsPDF called but view model has been deallocated; aborting share flow")
            return
        }
        vm.shareCoordinator.shareCurrentPageAsPDF(from: vm)
    }

    func shareDownloadFile(_ file: DownloadFile) {
        guard let vm else {
            Self.logger.error("Lifecycle mismatch: shareDownloadFile called but view model has been deallocated; aborting share flow")
            return
        }
        let anchor = vm.activeStore?.webViewHandle?.webView
        vm.shareCoordinator.shareDownloadFile(file.url, anchorView: anchor)
    }
    // MARK: - Scroll Physics
    func updateScrollPhysics(contentOffset: CGPoint, scrollView: UIScrollView) {
        let now = CACurrentMediaTime()
        // First sample (or post-reset): establish a baseline and avoid treating initial/restore
        // offsets as user intent.
        if lastScrollTime == 0 {
            lastScrollOffset = contentOffset
            lastScrollTime = now
            scrollVelocitySamples.removeAll()
            scrollVelocity = 0
            scrollDirection = .none
            isDragging = scrollView.isDragging
            isDecelerating = scrollView.isDecelerating
            return
        }
        let deltaTime = now - lastScrollTime
        let deltaY = contentOffset.y - lastScrollOffset.y
        if abs(deltaY) > 0.1 {
            lastScrollInteractionTime = now
        }
        let wasDecelerating = isDecelerating
        isDragging = scrollView.isDragging
        isDecelerating = scrollView.isDecelerating
        // Safari-grade invariant: while the web view is launching/attaching,
        // ignore all scroll-driven chrome effects. ContentOffset/inset changes during
        // attach can otherwise shift the chrome even without user input.
        if page.isLaunching || page.webViewAttached == false {
            lastScrollOffset = contentOffset
            lastScrollTime = now
            return
        }
        if abs(deltaY) > 1.0 {
            scrollDirection = deltaY > 0 ? .down : .up
        } else {
            scrollDirection = .none
        }
        if deltaTime > 0 {
            let velocity = deltaY / CGFloat(deltaTime)
            scrollVelocitySamples.append(velocity)
            if scrollVelocitySamples.count > Self.maxVelocitySamples {
                scrollVelocitySamples.removeFirst()
            }
            scrollVelocity = scrollVelocitySamples.reduce(0, +) / CGFloat(scrollVelocitySamples.count)
        }
        // Feed the pure state machine. Height is derived from snapshot.
        // Safari iPad landscape should not collapse to a single row.
        if chromeStyle != .padLandscapeSafari {
            // Do not collapse while address bar is focused or overview is visible.
            if chromeSnapshot.isEditing == false, chromeSnapshot.state != .overview {
                applyScrollDelta(deltaY: deltaY, isDragging: scrollView.isDragging, isDecelerating: scrollView.isDecelerating)
            } else {
                // While editing/overview is active, ignore scroll-driven chrome updates.
                // Critically: do NOT reset/adjust chromeHeight or chromeOffset here.
            }
            dispatchChrome(.scroll(y: contentOffset.y, velocityY: scrollVelocity))
        }
        if wasDecelerating && !isDecelerating {
            snapToNearestState()
        }
        lastScrollOffset = contentOffset
        lastScrollTime = now
    }
    private func snapToNearestState() {
        // Safari-like snap when scrolling ends.
        lastScrollInteractionTime = CACurrentMediaTime()
        let target: CGFloat = (scrollProgress >= uxPolicy.chromeCollapse.snapThreshold) ? 1 : 0
        applyScrollProgress(target, animated: true)
    }
    private func applyScrollDelta(deltaY: CGFloat, isDragging: Bool, isDecelerating: Bool) {
        guard abs(deltaY) > 0.1 else { return }
        // Safari-like: collapsing the bar should take meaningfully more scroll distance than the
        // raw height delta, and revealing should respond quickly to small upward scrolls.
        let heightRange = max(1, maxChromeHeight - minChromeHeight)
        let collapseDistance = max(
            uxPolicy.chromeCollapse.collapseDistanceMin,
            heightRange * uxPolicy.chromeCollapse.collapseDistanceHeightMultiplier
        )
        var deltaProgress = deltaY / collapseDistance
        if deltaY < 0 {
            deltaProgress *= uxPolicy.chromeCollapse.revealBoostMultiplier
        }
        let newProgress = scrollProgress + deltaProgress
        // While finger-driven (drag/decelerate), follow the scroll without animation to avoid jitter.
        // Snap uses interactiveSpring in `snapToNearestState()`.
        applyScrollProgress(newProgress, animated: (isDragging == false && isDecelerating == false))
    }
    private func applyScrollProgress(_ progress: CGFloat, animated: Bool) {
        let clamped = max(0, min(1, progress))
        let update = {
            self.interaction.scrollProgress = clamped
            self.interaction.chromeHeight = self.maxChromeHeight - (self.maxChromeHeight - self.minChromeHeight) * clamped
            self.interaction.chromeOffset = 0
        }
        if animated {
            let spring = uxPolicy.chromeCollapse.snapSpring
            withAnimation(.interactiveSpring(response: spring.response, dampingFraction: spring.dampingFraction, blendDuration: spring.blendDuration)) {
                update()
            }
        } else {
            update()
        }
    }
    private func resetScrollCollapse(animated: Bool) {
        applyScrollProgress(0, animated: animated)
    }
    private func resetScrollTrackingBaseline() {
        lastScrollTime = 0
        lastScrollOffset = .zero
        scrollVelocitySamples.removeAll()
        scrollVelocity = 0
        scrollDirection = .none
    }
    private func updateChromeInteractionState() {
        interaction.isURLFocused = chromeSnapshot.isAddressFocused
    }
}
