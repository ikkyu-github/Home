import Foundation
import SafariLikeContracts
import SwiftUI
import Combine
import CoreGraphics
import SafariLikeCoreKit
import SafariLikeUXKit
// MARK: - Typealiases
typealias TabID = UUID
/// Safari-style split browser ViewModel (composition + wiring only)
enum CompanionSection {
    case bookmarks
    case history
    case downloads
}
@MainActor
final class SplitBrowserViewModel: ObservableObject {
    // ...existing code...
    // MARK: - Mutation Boundary
    /// Synchronous mutation boundary for non-view-update contexts.
    func mutate(_ block: () -> Void) {
        block()
    }
    /// Asynchronous mutation boundary to ensure @Published changes happen outside SwiftUI view updates.
    func mutateAsync(_ block: @escaping () -> Void) {
        Task { @MainActor in
            block()
        }
    }
    // MARK: Glue: Dependencies
    private let sceneID: String
    // MARK: - Window session (Source of truth)
    let windowSession: SafariLikeCoreKit.WindowSession
    let windowCoordinator: SafariLikeCoreKit.WindowSessionCoordinator
    private var windowSessionCancellables = Set<AnyCancellable>()
    /// Internal: used for per-scene lifecycle/state scoping.
    internal var lifecycleSceneID: String { sceneID }
    internal weak var runtimeContext: SceneRuntimeContext?
    func setRuntimeContext(_ context: SceneRuntimeContext) {
        self.runtimeContext = context
    }
    let normalSessionStore: BrowserSessionStore
    let privateSessionStore: BrowserSessionStore
    let bookmarkStore: BookmarkStore
    let readingListStore: ReadingListStore
    let historyStore: HistoryStore
    /// Website preferences persistence interface (protocol-based).
    ///
    /// Concrete implementation is injected via BrowserEnvironment and
    /// typically provided by SafariLikeUIKit.WebsitePreferencesStore
    /// or a core-default implementation.
    let websitePreferencesStore: WebsitePreferencesProviding
    let downloadStore: any DownloadProviding
    let websiteDataService: any WebsiteDataServicing
    let privacyReportEngine: PrivacyReportEngine
    let privacyReportSnapshotStore: PrivacyReportSnapshotStore
    let formFillPolicyEngine: FormFillPolicyEngine
    let autofillStatusService: AutofillStatusService
    let userScriptStore: UserScriptStore
    private let configuration: SafariLikeConfiguration
    private let thumbnailStore: any ThumbnailCapturing
    let normalTabRegistry: SafariLikeCoreKit.TabRegistry
    let privateTabRegistry: SafariLikeCoreKit.TabRegistry
    let normalPaneContexts: [PaneID: PaneContext]
    let privatePaneContexts: [PaneID: PaneContext]
    // Protocol Adoption: Use ContentBlockingProviding for contentBlockerManagerInstance
    let contentBlockerManagerInstance: (any ContentBlockingProviding)?
    internal let defaultHomeURLString: String
    /// Keep initial selection info as immutable stored values (safe for lazy runtime init).
    private let initialActiveTabID: UUID
    private let initialStartURLString: String
    // MARK: - State (Reducer-style snapshot)
    @Published var state: State = .initial()
    // Lightweight callback hooks for host containers
    var onTabClosed: ((UUID) -> Void)?
    // MARK: UI-observable mirrors (read-only; source of truth is WindowSession)
    @Published private(set) var isPrivateMode: Bool = false
    @Published var isSidebarVisible: Bool = false
    @Published private(set) var sidebarContent: SidebarContent = .menu
    @Published var isTabOverviewVisible = false
    @Published var isTabOverviewPresented: Bool = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var pageProgress: Double = 0
    @Published var isBottomBarCollapsed: Bool = false

    // MARK: - Policy Decisions (value-type)
    /// Single source of truth for the active tab's web-content visibility decision.
    ///
    /// Evaluated from a snapshot and applied declaratively by the UI (e.g. TabRenderer).
    @Published var activeWebContentVisibilityDecision: WebContentVisibilityPolicy.Decision = .showNonWebContent
    #if DEBUG
    @Published private(set) var debugLastNavigationEvent: String = "<none>"
    @Published private(set) var debugLastNavigationEventAt: Date = .distantPast
    private var debugPrevIsLoading: Bool = false
    private var debugPrevPageProgress: Double = 0
    #endif
    // MARK: Website preferences lifecycle gating
    /// True when the owning scene is in the foreground (active).
    @Published var isSceneActive: Bool = false
    /// Returns true when it is safe to touch WebKit/WebView based
    /// on current scene and web view readiness.
    // MARK: Companion state (Glue)
    @Published var isAutoCompanionEnabled: Bool = true
    @Published var isCompanionVisible: Bool = false
    @Published var isRelatedVisible: Bool = false
    @Published var isLandscapeSplitActive: Bool = false
    @Published private(set) var layoutEnvironment: LayoutEnvironment = .compactSinglePane
    @Published var didUserOverrideCompanionVisibility: Bool = false
    @Published var splitRatio: CGFloat = SplitBrowserConstants.defaultSplitRatio
    @Published var relatedPresentation: RelatedPresentation = .hidden
    /// Portrait Related sheet height as a fraction of the available container height.
    /// This is bound to the draggable bottom sheet and persists across layout changes.
    @Published var relatedPopupHeightFraction: CGFloat = SplitBrowserConstants.relatedSnapMid
    @Published var relatedAnimation: Animation? = .easeOut(duration: 0.25)
    @Published var isLandscapeDevice: Bool = false
    var activeCompanionSection: CompanionSection? = nil
    @Published private(set) var companionItems: [SafariLikeCoreKit.CompanionItem] = []
    /// Single source of truth for Related data.
    /// `companionItems` remains the storage; all Related UI should bind to this.
    var relatedItems: [SafariLikeCoreKit.CompanionItem] { companionItems }
    func setAutoCompanionEnabled(_ isEnabled: Bool) {
        mutateAsync {
            self.isAutoCompanionEnabled = isEnabled
            self.state.isAutoCompanionEnabled = isEnabled
        }
    }
    // MARK: Suggestions (AddressBar)
    struct OmniboxSuggestion: Identifiable, Equatable {
        enum Kind: Equatable { case history, bookmark, readingList, search }
        let id = UUID()
        let title: String
        let subtitle: String?
        let urlString: String?
        let query: String?
        let kind: Kind
    }
    @Published var suggestions: [OmniboxSuggestion] = []
    /// Changes to this value force a full SwiftUI subtree re-render.
    /// Used by FaultManager recovery for UI-domain faults.
    @Published var uiRerenderNonce: UUID = UUID()
    // MARK: - Web content visibility (UI reconciler)
    /// Prevent repeated forced re-renders for the same tab while a mismatch persists.
    internal var didReconcileWebVisibilityForTabIDs: Set<UUID> = []
    // MARK: Domains
    lazy var nav = SplitBrowserNavigationDomain(root: self)
    lazy var bar = SplitBrowserAddressBarDomain(root: self, initialURLString: initialStartURLString)
    lazy var layout = SplitBrowserLayoutDomain(root: self)
    lazy var companion = SplitBrowserCompanionDomain(root: self)
    lazy var tabsDomain = SplitBrowserTabsDomain(root: self)
    lazy var glue = SplitBrowserStateGlue(root: self)
    // MARK: Share
    let shareCoordinator = ShareCoordinator()
    // MARK: Runtime controllers (LAZY to avoid self-use-before-init)
    private(set) lazy var tabManager: TabManager = {
        TabManager(
            normalSessionStore: normalSessionStore,
            privateSessionStore: privateSessionStore,
            normalTabRegistry: normalTabRegistry,
            privateTabRegistry: privateTabRegistry,
            normalPaneContexts: normalPaneContexts,
            privatePaneContexts: privatePaneContexts,
            defaultHomeURLString: defaultHomeURLString,
            historyStore: historyStore,
            bookmarkStore: bookmarkStore,
            downloadStore: downloadStore,
            initialActiveTabID: initialActiveTabID,
            windowID: sceneID
        )
    }()
    /// Central navigation service for the current window.
    /// SplitBrowserViewModel is the single strong owner; other
    /// collaborators receive references from here.
    private(set) lazy var navigationService: NavigationService = {
        let service = NavigationService(tabManager: tabManager)
        tabManager.navigationService = service
        return service
    }()
    private(set) lazy var browserActions: BrowserActions = {
        BrowserActionsImpl(sessionStore: sessionStore, tabManager: tabManager, navigation: nav)
    }()
    private(set) lazy var addressBar: AddressBarController = {
        let controller = AddressBarController(
            navigation: navigationService,
            normalSessionStore: normalSessionStore,
            historyStore: historyStore,
            bookmarkStore: bookmarkStore,
            readingListStore: readingListStore
        )
        controller.configureStateMachine(initialDisplayed: initialStartURLString)
        controller.addressText = initialStartURLString
        return controller
    }()
    private(set) lazy var companionController: CompanionController = {
        CompanionController(
            collapsedFraction: SplitBrowserConstants.relatedCollapsedFraction,
            snapMid: SplitBrowserConstants.relatedSnapMid
        )
    }()
    // MARK: Init
    init(
        environment: BrowserEnvironment,
        windowSession: SafariLikeCoreKit.WindowSession,
        windowCoordinator: SafariLikeCoreKit.WindowSessionCoordinator,
        normalSessionStore: BrowserSessionStore,
        privateSessionStore: BrowserSessionStore,
        normalTabRegistry: SafariLikeCoreKit.TabRegistry,
        privateTabRegistry: SafariLikeCoreKit.TabRegistry,
        normalPaneContexts: [PaneID: PaneContext],
        privatePaneContexts: [PaneID: PaneContext],
        contentBlockerManager: (any ContentBlockingProviding)?,
        initialURL: String? = nil
    ) {
        // --- PHASE 0: Prepare value/store dependencies (NO self usage) ---
        self.sceneID = environment.sceneID
        self.windowSession = windowSession
        self.windowCoordinator = windowCoordinator
        let normalSessionStore = normalSessionStore
        let privateSessionStore = privateSessionStore
        let bookmarkStore = environment.bookmarkStore
        let readingListStore = environment.readingListStore
        let historyStore = environment.historyStore
        let websitePreferencesStore = environment.websitePreferencesStore
        let siteSettingsStore = environment.siteSettingsStore
        let downloadStore = environment.downloadStore
        let websiteDataService = environment.websiteDataService
        let privacyReportSnapshotStore = environment.privacyReportSnapshotStore
        let formFillPolicyEngine = environment.formFillPolicyEngine
        let autofillStatusService = environment.autofillStatusService
        let userScriptStore = environment.userScriptStore
        let configuration = environment.configuration
        let defaultHomeURLString = configuration.defaultHomeURLString
        let contentBlockerManagerInstance = contentBlockerManager
        let initialTabID: UUID =
            normalSessionStore.selectedTabID
            ?? normalSessionStore.tabs.first?.id
            ?? normalSessionStore.addTab()
        if let initialURL, !initialURL.isEmpty {
            normalSessionStore.updateTab(id: initialTabID, urlString: initialURL)
        }
        let startURLString: String =
            (initialURL?.isEmpty == false ? initialURL : nil)
            ?? normalSessionStore.tabs.first(where: { $0.id == initialTabID })?.urlString
            ?? defaultHomeURLString
        // --- PHASE 1: assign stored properties (still NO self usage that depends on uninit) ---
        self.normalSessionStore = normalSessionStore
        self.privateSessionStore = privateSessionStore
        self.bookmarkStore = bookmarkStore
        self.readingListStore = readingListStore
        self.historyStore = historyStore
        self.websitePreferencesStore = websitePreferencesStore
        self.downloadStore = downloadStore
        self.thumbnailStore = environment.thumbnailStore
        self.websiteDataService = websiteDataService
        self.privacyReportSnapshotStore = privacyReportSnapshotStore
        self.formFillPolicyEngine = formFillPolicyEngine
        self.autofillStatusService = autofillStatusService
        self.userScriptStore = userScriptStore
        self.privacyReportEngine = PrivacyReportEngine(
            dependencies: .init(
                websiteDataService: websiteDataService,
                siteSettingsStore: siteSettingsStore,
                websitePreferencesStore: websitePreferencesStore
            )
        )
        self.configuration = configuration
        self.defaultHomeURLString = defaultHomeURLString
        self.contentBlockerManagerInstance = contentBlockerManagerInstance
        self.normalTabRegistry = normalTabRegistry
        self.privateTabRegistry = privateTabRegistry
        self.normalPaneContexts = normalPaneContexts
        self.privatePaneContexts = privatePaneContexts
        self.initialActiveTabID = initialTabID
        self.initialStartURLString = startURLString
        // --- PHASE 2: post-init wiring (safe now; lazy props are considered initialized) ---
        bindWindowSession()
        bindRuntime()
        // UI-first restore: mark selection now, activate WKWebView lazily on first view appearance.
        normalSessionStore.selectTab(id: initialTabID)
        tabManager.activeTabID = initialTabID
        refreshActiveWebContentVisibilityDecision()
    }
    private func bindWindowSession() {
        windowSessionCancellables.removeAll()
        windowSession.$browsingProfile
            .receive(on: RunLoop.main)
            .sink { [weak self] profile in
                guard let self else { return }
                self.mutateAsync {
                    self.isPrivateMode = (profile == .private)
                    self.tabManager.isPrivateMode = self.isPrivateMode
                    self.downloadStore.setActiveProfile(profile)
                    self.glue.bindSessionSelection(for: self.sessionStore)
                }
            }
            .store(in: &windowSessionCancellables)
        windowSession.$sidebarMode
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in
                guard let self else { return }
                self.mutateAsync {
                    switch mode {
                    case .hidden:
                        self.isSidebarVisible = false
                        self.sidebarContent = .menu
                    case .visible(let content):
                        self.isSidebarVisible = true
                        self.sidebarContent = content
                    @unknown default:
                        self.isSidebarVisible = false
                        self.sidebarContent = .menu
                    }
                }
            }
            .store(in: &windowSessionCancellables)
    }
    // MARK: - Chrome State
    /// Chrome state (toolbars, find bar, downloads, etc.).
    /// SplitBrowserViewModel is the primary owner; other layers
    /// observe it via SwiftUI environment or explicit injection.
    private(set) lazy var chrome: BrowserChromeState = {
        let thumbnailsAdapter = ThumbnailChromeAdapter(store: thumbnailStore)
        return BrowserChromeState(
            downloads: downloadStore,
            thumbnails: thumbnailsAdapter,
            viewModel: self
        )
    }()
    // MARK: - Runtime binding
    private func bindRuntime() {
        tabManager.isPrivateMode = isPrivateMode
        addressBar.onCollapseReset = { [weak self] in
            self?.mutateAsync {
                self?.isBottomBarCollapsed = false
                self?.chrome.commitAddressEditing()
            }
        }
        tabManager.onNavStateChange = { [weak self] canGoBack, canGoForward, isLoading, pageProgress in
            guard let self else { return }
            self.mutateAsync {
                self.canGoBack = canGoBack
                self.canGoForward = canGoForward
                self.isLoading = isLoading
                self.pageProgress = pageProgress
                #if DEBUG
                let event: String? = {
                    if self.debugPrevIsLoading == false, isLoading == true { return "didStartLoading" }
                    if self.debugPrevIsLoading == true, isLoading == false { return "didFinishLoading" }
                    if pageProgress < self.debugPrevPageProgress { return "progressReset" }
                    return nil
                }()
                if let event {
                    self.debugLastNavigationEvent = event
                    self.debugLastNavigationEventAt = Date()
                }
                self.debugPrevIsLoading = isLoading
                self.debugPrevPageProgress = pageProgress
                #endif
                // Feed the VM-owned address bar state machine.
                self.bar.onLoadingChanged(isLoading: isLoading, progress: pageProgress)
            }
        }

        tabManager.onActiveTabChanged = { [weak self] _ in
            guard let self else { return }
            self.mutateAsync {
                self.refreshActiveWebContentVisibilityDecision()
            }
        }
        tabManager.onAddressShouldSync = { [weak self] url in
            guard let self else { return }
            if !self.isAddressFocusedExternally {
                self.addressBar.onNavigationCommitted(urlString: url)
            }
			// AddressBarStateMachine will ignore commits while editing.
			self.bar.onNavigationCommitted(urlString: url)
        }
        tabManager.onCompanionItemsUpdate = { [weak self] items in
            self?.mutateAsync {
                self?.companionItems = items
                self?.companionController.updateCompanionItems(empty: items.isEmpty)
            }
        }
        tabManager.onWebInputFocused = { [weak self] in
            self?.mutateAsync {
                self?.bar.send(SafariLikeContracts.AddressBarEvent.focusChanged(isFocused: false))
            }
        }
        glue.bindSessionSelection(for: normalSessionStore)
        glue.bind()
    }
}
