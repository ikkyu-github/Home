import Foundation
import SafariLikeContracts
import Combine

/// ONE authoritative session state snapshot for a single window.
///
/// This is the only persisted representation of session state.
/// If a value can be derived from other fields, it must not be stored.
public struct WindowSessionState: Codable, Sendable, Equatable {
    public enum ActivePane: String, Codable, Sendable, Equatable {
        case left
        case right
    }

    public struct SplitViewState: Codable, Sendable, Equatable {
        public var isEnabled: Bool
        public var ratio: Double
        public var activePane: ActivePane

        /// Best-effort: the active tab IDs for each pane when split is enabled.
        ///
        /// These cannot be derived from `tabs` alone.
        public var leftTabID: UUID?
        public var rightTabID: UUID?

        public init(
            isEnabled: Bool = false,
            ratio: Double = 0.5,
            activePane: ActivePane = .left,
            leftTabID: UUID? = nil,
            rightTabID: UUID? = nil
        ) {
            self.isEnabled = isEnabled
            self.ratio = ratio
            self.activePane = activePane
            self.leftTabID = leftTabID
            self.rightTabID = rightTabID
        }
    }

    public struct UIState: Codable, Sendable, Equatable {
        public var isSidebarVisible: Bool
        public var isRelatedVisible: Bool

        public init(isSidebarVisible: Bool = false, isRelatedVisible: Bool = false) {
            self.isSidebarVisible = isSidebarVisible
            self.isRelatedVisible = isRelatedVisible
        }
    }

    public struct RecentlyClosedTab: Codable, Sendable, Equatable {
        public var tab: BrowserTab
        public var navigation: TabNavigationState?
        public var closedAt: Date
        /// Original index in `tabs` at the time of close.
        public var originalIndex: Int?

        public init(
            tab: BrowserTab,
            navigation: TabNavigationState?,
            closedAt: Date = Date(),
            originalIndex: Int? = nil
        ) {
            self.tab = tab
            self.navigation = navigation
            self.closedAt = closedAt
            self.originalIndex = originalIndex
        }
    }

    public var tabs: [BrowserTab]
    public var selectedTabID: UUID?
    public var tabGroups: [BrowserTabGroup]
    public var selectedTabGroupID: UUID?

    /// Bounded LIFO stack for undo-close.
    public var recentlyClosed: [RecentlyClosedTab]

    /// Durable per-tab navigation state (independent of WebKit back/forward lists).
    ///
    /// Keyed by `BrowserTab.id`.
    public var tabNavigationByID: [UUID: TabNavigationState]

    public var splitView: SplitViewState
    public var ui: UIState

    private enum CodingKeys: String, CodingKey {
        case tabs
        case selectedTabID
        case tabGroups
        case selectedTabGroupID
        case recentlyClosed
        case tabNavigationByID
        case splitView
        case ui
    }

    public init(
        tabs: [BrowserTab],
        selectedTabID: UUID?,
        tabGroups: [BrowserTabGroup],
        selectedTabGroupID: UUID?,
        recentlyClosed: [RecentlyClosedTab] = [],
        tabNavigationByID: [UUID: TabNavigationState] = [:],
        splitView: SplitViewState = .init(),
        ui: UIState = .init()
    ) {
        self.tabs = tabs
        self.selectedTabID = selectedTabID
        self.tabGroups = tabGroups
        self.selectedTabGroupID = selectedTabGroupID
        self.recentlyClosed = recentlyClosed
        self.tabNavigationByID = tabNavigationByID
        self.splitView = splitView
        self.ui = ui
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Safari-like resilience: don't let a single corrupt tab/group nuke the whole window.
        let lossyTabs = (try? container.decode([LossyDecodable<BrowserTab>].self, forKey: .tabs)) ?? []
        self.tabs = lossyTabs.compactMap { $0.value }
        self.selectedTabID = try? container.decode(UUID?.self, forKey: .selectedTabID)

        let lossyGroups = (try? container.decode([LossyDecodable<BrowserTabGroup>].self, forKey: .tabGroups)) ?? []
        self.tabGroups = lossyGroups.compactMap { $0.value }
        self.selectedTabGroupID = try? container.decode(UUID?.self, forKey: .selectedTabGroupID)

        let lossyClosed = (try? container.decode([LossyDecodable<RecentlyClosedTab>].self, forKey: .recentlyClosed)) ?? []
        self.recentlyClosed = lossyClosed.compactMap { $0.value }

        self.tabNavigationByID = (try? container.decode([UUID: TabNavigationState].self, forKey: .tabNavigationByID)) ?? [:]

        self.splitView = (try? container.decode(SplitViewState.self, forKey: .splitView)) ?? SplitViewState()
        self.ui = (try? container.decode(UIState.self, forKey: .ui)) ?? UIState()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tabs, forKey: .tabs)
        try container.encode(selectedTabID, forKey: .selectedTabID)
        try container.encode(tabGroups, forKey: .tabGroups)
        try container.encode(selectedTabGroupID, forKey: .selectedTabGroupID)
        try container.encode(recentlyClosed, forKey: .recentlyClosed)
        try container.encode(tabNavigationByID, forKey: .tabNavigationByID)
        try container.encode(splitView, forKey: .splitView)
        try container.encode(ui, forKey: .ui)
    }
}

private struct LossyDecodable<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try? container.decode(T.self)
    }
}

@MainActor
public final class BrowserSessionStore: ObservableObject {

    @MainActor
    public func snapshotTabIDs() -> [UUID] {
        tabs.map { $0.id }
    }

    public enum PersistenceMode {
        case disk(filename: String)
        /// Directory-bucketed per-scene persistence.
        ///
        /// Uses `BrowserCore.SceneSessionStore` under Application Support `sessions/<sceneID>/...`.
        /// If `legacyFilename` is provided, best-effort migration from the legacy single-file
        /// snapshot will be performed when no bucket exists.
        case sceneBucket(sceneID: String, legacyFilename: String? = nil)
        case memory
    }

    // Public state (คง API เดิม เพื่อไม่กระทบไฟล์อื่น)
    @Published public private(set) var tabs: [BrowserTab]
    @Published public private(set) var selectedTabID: UUID?
    // ต้องเป็น public เพื่อให้ UI framework (เช่น SafariLikeKit) อ่านได้ข้าม module
    @Published public private(set) var tabGroups: [BrowserTabGroup]
    @Published public private(set) var selectedTabGroupID: UUID?
    @Published public private(set) var recentlyClosed: [WindowSessionState.RecentlyClosedTab]

    // Window-level UI/layout state (persisted as part of WindowSessionState).
    @Published public private(set) var splitViewState: WindowSessionState.SplitViewState
    @Published public private(set) var uiState: WindowSessionState.UIState

    // Durable per-tab navigation (persisted as part of WindowSessionState).
    @Published public private(set) var tabNavigationByID: [UUID: TabNavigationState]

    private let persistence: PersistenceMode
    private var saveTask: Task<Void, Never>?
    private let fileStore = JSONFileStoreActor()
    private let sceneSessionStore = SceneSessionStore()
    private var memorySnapshot: WindowSessionState?

    private var didFinishInitialLoad = false
    private var initialLoadContinuations: [CheckedContinuation<Void, Never>] = []

    /// Await the initial on-disk session load completing.
    ///
    /// This is used by Safari-like restoration flows to ensure UI can render
    /// snapshots first, and web loading is triggered only after the model is ready.
    @MainActor
    public func awaitInitialLoad() async {
        if didFinishInitialLoad { return }
        await withCheckedContinuation { continuation in
            initialLoadContinuations.append(continuation)
        }
    }

    public init(persistence: PersistenceMode) {
        let initialTab = BrowserTab()
        let initialTabs = [initialTab]

        // Initialize stored properties (avoid reading self.* during init; assignment only).
        self.persistence = persistence
        self.tabs = initialTabs
        self.tabGroups = []
        self.selectedTabGroupID = nil
        self.selectedTabID = initialTab.id
        self.recentlyClosed = []
        self.splitViewState = .init()
        self.uiState = .init()
        self.tabNavigationByID = [initialTab.id: Self.makeInitialNavigationState(from: initialTab)]

        // Defer async restore until after init returns (boot race guard without touching self state reads during init).
        Task { @MainActor [weak self] in
            self?.startAsyncLoad()
        }
    }

    private func startAsyncLoad() {
        // Load asynchronously
        Task {
            let snapshot: WindowSessionState
            switch self.persistence {
            case .disk(let filename):
                snapshot = await self.fileStore.load(
                    filename: filename,
                    defaultValue: WindowSessionState(
                        tabs: [BrowserTab()],
                        selectedTabID: nil,
                        tabGroups: [],
                        selectedTabGroupID: nil
                    )
                )
            case .sceneBucket(let sceneID, let legacyFilename):
                snapshot = await self.sceneSessionStore.loadWindowSessionState(sceneID: sceneID, legacyFilename: legacyFilename)
            case .memory:
                snapshot = self.memorySnapshot
                    ?? WindowSessionState(tabs: [BrowserTab()], selectedTabID: nil, tabGroups: [], selectedTabGroupID: nil)
            }
            await MainActor.run { [weak self] in
                guard let self else { return }

                let loadedTabs = snapshot.tabs.isEmpty ? [BrowserTab()] : snapshot.tabs
                self.tabs = loadedTabs

                // Boot race guard: don't override a valid selection if UI/system already picked a tab.
                if self.selectedTabID == nil || !loadedTabs.contains(where: { $0.id == self.selectedTabID }) {
                    self.selectedTabID = snapshot.selectedTabID ?? loadedTabs.first?.id
                }

                self.tabGroups = snapshot.tabGroups
                self.selectedTabGroupID = snapshot.selectedTabGroupID
                self.recentlyClosed = snapshot.recentlyClosed

                // Navigation state: prefer persisted state, else derive a minimal seed from tabs.
                self.tabNavigationByID = snapshot.tabNavigationByID
                self.normalizeTabStateConsistency()

                self.splitViewState = snapshot.splitView
                self.uiState = snapshot.ui

                // Unblock any restoration flows waiting for the initial load.
                self.didFinishInitialLoad = true
                let continuations = self.initialLoadContinuations
                self.initialLoadContinuations.removeAll()
                for c in continuations { c.resume() }
            }
        }
    }

    private func normalizeTabStateConsistency() {
        normalizeGroups()
        normalizePinnedOrdering()
        ensureNavigationStateConsistency()
        trimRecentlyClosedIfNeeded()
    }

    private func normalizePinnedOrdering() {
        // Stable partition: pinned first, then unpinned.
        let pinned = tabs.filter { $0.isPinned }
        let unpinned = tabs.filter { !$0.isPinned }
        tabs = pinned + unpinned
    }

    private func normalizeGroups() {
        let groupIDs = Set(tabGroups.map { $0.id })

        // Clear invalid references.
        for idx in tabs.indices {
            if let gid = tabs[idx].groupID, groupIDs.contains(gid) == false {
                tabs[idx].groupID = nil
            }
        }

        // Rebuild group tab lists from the authoritative tab array order.
        for gIdx in tabGroups.indices {
            let gid = tabGroups[gIdx].id
            let nextIDs = tabs.compactMap { $0.groupID == gid ? $0.id : nil }
            if tabGroups[gIdx].tabIDs != nextIDs {
                tabGroups[gIdx].tabIDs = nextIDs
                tabGroups[gIdx].lastModifiedAt = Date()
            }
        }

        // Drop selected group if it doesn't exist.
        if let sel = selectedTabGroupID, groupIDs.contains(sel) == false {
            selectedTabGroupID = nil
        }
    }

    private func trimRecentlyClosedIfNeeded(maxCount: Int = 20) {
        if recentlyClosed.count > maxCount {
            recentlyClosed.removeLast(recentlyClosed.count - maxCount)
        }
    }

    public convenience init(filename: String) {
        self.init(persistence: .disk(filename: filename))
    }

    deinit {
        saveTask?.cancel()
    }

    public func saveNow() {
        let snapshot = WindowSessionState(
            tabs: tabs,
            selectedTabID: selectedTabID,
            tabGroups: tabGroups,
            selectedTabGroupID: selectedTabGroupID,
            recentlyClosed: recentlyClosed,
            tabNavigationByID: tabNavigationByID,
            splitView: splitViewState,
            ui: uiState
        )
        switch persistence {
        case .disk(let filename):
            Task {
                await fileStore.save(filename: filename, value: snapshot)
            }
        case .sceneBucket(let sceneID, _):
            Task {
                await sceneSessionStore.saveWindowSessionState(sceneID: sceneID, snapshot: snapshot)
                await sceneSessionStore.saveContinueBrowsingSummary(
                    sceneID: sceneID,
                    summary: Self.makeContinueBrowsingSummary(sceneID: sceneID, snapshot: snapshot)
                )
            }
        case .memory:
            memorySnapshot = snapshot
        }
    }

    private static func makeContinueBrowsingSummary(sceneID: String, snapshot: WindowSessionState) -> SceneSessionSummary {
        let selectedTab: BrowserTab? = {
            guard let id = snapshot.selectedTabID else { return nil }
            return snapshot.tabs.first(where: { $0.id == id })
        }()
        let url: URL? = {
            let s = (selectedTab?.urlString ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard s.isEmpty == false else { return nil }
            return URL(string: s)
        }()
        return SceneSessionSummary(
            identity: SceneIdentity(sceneID: sceneID, windowID: nil),
            selectedURL: url,
            selectedTitle: selectedTab?.title,
            tabCount: snapshot.tabs.count,
            updatedAt: Date()
        )
    }

    // MARK: - Window Session State (Layout/UI)

    @MainActor
    public func updateSplitViewState(_ state: WindowSessionState.SplitViewState) {
        splitViewState = state
        scheduleSave()
    }

    @MainActor
    public func updateUIState(_ state: WindowSessionState.UIState) {
        uiState = state
        scheduleSave()
    }

    /// Replace the current tab list with a provided set of tabs.
    ///
    /// This is intended for session restore flows that need to preserve stable
    /// tab IDs (e.g. journaling) without creating any WebKit objects.
    ///
    /// Notes:
    /// - If `tabs` is empty, a single placeholder tab is created.
    /// - If `selectedTabID` is nil/invalid, selection falls back to the first tab.
    @MainActor
    public func replaceAllTabs(_ tabs: [BrowserTab], selectedTabID: UUID?) {
        self.tabs = tabs.isEmpty ? [BrowserTab()] : tabs

        // Keep navigation state for stable IDs when possible.
        ensureNavigationStateConsistency()

        if let requested = selectedTabID,
           self.tabs.contains(where: { $0.id == requested }) {
            self.selectedTabID = requested
        } else {
            self.selectedTabID = self.tabs.first?.id
        }

        scheduleSave()
    }

    /// Replace tabs and tab groups in one operation.
    ///
    /// Intended for journal/checkpoint restore flows that need stable IDs.
    @MainActor
    public func replaceAllTabsAndGroups(
        _ tabs: [BrowserTab],
        selectedTabID: UUID?,
        tabGroups: [BrowserTabGroup],
        selectedTabGroupID: UUID?
    ) {
        self.tabs = tabs.isEmpty ? [BrowserTab()] : tabs

        ensureNavigationStateConsistency()

        if let requested = selectedTabID,
           self.tabs.contains(where: { $0.id == requested }) {
            self.selectedTabID = requested
        } else {
            self.selectedTabID = self.tabs.first?.id
        }

        self.tabGroups = tabGroups
        if let selectedTabGroupID,
           tabGroups.contains(where: { $0.id == selectedTabGroupID }) {
            self.selectedTabGroupID = selectedTabGroupID
        } else {
            self.selectedTabGroupID = nil
        }

        scheduleSave()
    }

    /// Persist session to disk immediately.
    public func persist() {
        saveNow()
    }

    @discardableResult
    public func addTab() -> UUID {
        let tab = BrowserTab()
        let pinnedCount = tabs.reduce(0) { $0 + ($1.isPinned ? 1 : 0) }
        tabs.insert(tab, at: min(pinnedCount, tabs.count))
        selectedTabID = tab.id
        tabNavigationByID[tab.id] = Self.makeInitialNavigationState(from: tab)
        normalizeTabStateConsistency()
        scheduleSave()
        return tab.id
    }

    public func selectTab(id: UUID) {
        selectedTabID = id
        if let idx = tabs.firstIndex(where: { $0.id == id }) {
            tabs[idx].lastVisitedAt = Date()
        }
        normalizeTabStateConsistency()
        scheduleSave()
    }

    public func closeTab(id: UUID) {
        closeTabInternal(id: id, recordRecentlyClosed: true)
    }

    private func closeTabInternal(id: UUID, recordRecentlyClosed: Bool) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[idx]

        if recordRecentlyClosed {
            recentlyClosed.insert(
                .init(tab: tab, navigation: tabNavigationByID[id], originalIndex: idx),
                at: 0
            )
            trimRecentlyClosedIfNeeded()
        }

        tabs.remove(at: idx)
        tabNavigationByID[id] = nil

        if tabs.isEmpty { tabs = [BrowserTab()] }

        // Selection fallback.
        if selectedTabID == id || selectedTabID == nil {
            selectedTabID = tabs.first?.id
        }

        normalizeTabStateConsistency()
        scheduleSave()
    }

    /// Undo the most recent tab close. Returns the restored tab ID.
    @discardableResult
    public func undoCloseLastTab() -> UUID? {
        guard recentlyClosed.isEmpty == false else { return nil }
        let record = recentlyClosed.removeFirst()

        var tab = record.tab
        if let gid = tab.groupID, tabGroups.contains(where: { $0.id == gid }) == false {
            tab.groupID = nil
        }

        let pinnedCount = tabs.reduce(0) { $0 + ($1.isPinned ? 1 : 0) }
        let desiredIndex = record.originalIndex ?? (tab.isPinned ? 0 : pinnedCount)

        let insertIndex: Int
        if tab.isPinned {
            insertIndex = max(0, min(desiredIndex, pinnedCount))
        } else {
            insertIndex = max(pinnedCount, min(desiredIndex, tabs.count))
        }

        tabs.insert(tab, at: insertIndex)
        tabNavigationByID[tab.id] = record.navigation ?? Self.makeInitialNavigationState(from: tab)
        selectedTabID = tab.id

        normalizeTabStateConsistency()
        scheduleSave()
        return tab.id
    }

    public func updateTab(
        id: UUID?,
        title: String? = nil,
        urlString: String? = nil,
        lifecycleState: TabLifecycleState? = nil,
        discardLevel: TabDiscardLevel? = nil,
        restoreToken: TabRestoreToken? = nil,
        isPinned: Bool? = nil,
        isUserLocked: Bool? = nil
    ) {
        guard let id,
              let idx = tabs.firstIndex(where: { $0.id == id })
        else { return }

        var didUpdateNavigationOrTitle = false
        if let title {
            tabs[idx].title = title
            didUpdateNavigationOrTitle = true
        }
        if let urlString {
            tabs[idx].urlString = urlString
            didUpdateNavigationOrTitle = true
        }
        if let lifecycleState { tabs[idx].lifecycleState = lifecycleState }
        if let discardLevel { tabs[idx].discardLevel = discardLevel }
        if let restoreToken { tabs[idx].restoreToken = restoreToken }
        if let isPinned { tabs[idx].isPinned = isPinned }
        if let isUserLocked { tabs[idx].isUserLocked = isUserLocked }

        // Only bump lastVisitedAt for user-visible navigation/title changes.
        if didUpdateNavigationOrTitle {
            tabs[idx].lastVisitedAt = Date()
        }
        normalizeTabStateConsistency()
        scheduleSave()
    }

    /// Update discard/lifecycle metadata without mutating `lastVisitedAt`.
    ///
    /// Use this for background discard and memory mitigation so scoring remains meaningful.
    public func updateTabResourceState(
        id: UUID?,
        lifecycleState: TabLifecycleState? = nil,
        discardLevel: TabDiscardLevel? = nil,
        restoreToken: TabRestoreToken? = nil,
        clearRestoreToken: Bool = false
    ) {
        guard let id,
              let idx = tabs.firstIndex(where: { $0.id == id })
        else { return }

        if let lifecycleState { tabs[idx].lifecycleState = lifecycleState }
        if let discardLevel { tabs[idx].discardLevel = discardLevel }
        if let restoreToken { tabs[idx].restoreToken = restoreToken }
        if clearRestoreToken { tabs[idx].restoreToken = nil }

        normalizeTabStateConsistency()
        scheduleSave()
    }

    // MARK: - Tab Groups

    @discardableResult
    public func createTabGroup(name: String, color: BrowserTabGroup.TabGroupColor = .blue) -> UUID {
        let group = BrowserTabGroup(name: name, color: color)
        tabGroups.append(group)
        normalizeTabStateConsistency()
        scheduleSave()
        return group.id
    }

    public func selectTabGroup(id: UUID?) {
        selectedTabGroupID = id
        normalizeTabStateConsistency()
        scheduleSave()
    }

    public func deleteTabGroup(id: UUID) {
        // Move tabs from this group to no group
        for idx in tabs.indices {
            if tabs[idx].groupID == id {
                tabs[idx].groupID = nil
            }
        }
        tabGroups.removeAll { $0.id == id }
        if selectedTabGroupID == id {
            selectedTabGroupID = nil
        }
        normalizeTabStateConsistency()
        scheduleSave()
    }

    public func updateTabGroup(id: UUID, name: String? = nil, color: BrowserTabGroup.TabGroupColor? = nil) {
        guard let idx = tabGroups.firstIndex(where: { $0.id == id }) else { return }
        if let name { tabGroups[idx].name = name }
        if let color { tabGroups[idx].color = color }
        tabGroups[idx].lastModifiedAt = Date()
        normalizeTabStateConsistency()
        scheduleSave()
    }

    public func addTabToGroup(tabID: UUID, groupID: UUID) {
        guard let tabIdx = tabs.firstIndex(where: { $0.id == tabID }),
              tabGroups.contains(where: { $0.id == groupID }) else { return }
        tabs[tabIdx].groupID = groupID
        if let groupIdx = tabGroups.firstIndex(where: { $0.id == groupID }) {
            if !tabGroups[groupIdx].tabIDs.contains(tabID) {
                tabGroups[groupIdx].tabIDs.append(tabID)
                tabGroups[groupIdx].lastModifiedAt = Date()
            }
        }
        normalizeTabStateConsistency()
        scheduleSave()
    }

    func removeTabFromGroup(tabID: UUID) {
        guard let tabIdx = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        let oldGroupID = tabs[tabIdx].groupID
        tabs[tabIdx].groupID = nil
        if let oldGroupID,
           let groupIdx = tabGroups.firstIndex(where: { $0.id == oldGroupID }) {
            tabGroups[groupIdx].tabIDs.removeAll { $0 == tabID }
            tabGroups[groupIdx].lastModifiedAt = Date()
        }
        normalizeTabStateConsistency()
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            guard !Task.isCancelled, let self else { return }
            let snapshot = WindowSessionState(
                tabs: self.tabs,
                selectedTabID: self.selectedTabID,
                tabGroups: self.tabGroups,
                selectedTabGroupID: self.selectedTabGroupID,
                recentlyClosed: self.recentlyClosed,
                tabNavigationByID: self.tabNavigationByID,
                splitView: self.splitViewState,
                ui: self.uiState
            )
            switch self.persistence {
            case .disk(let filename):
                await self.fileStore.save(filename: filename, value: snapshot)
            case .sceneBucket(let sceneID, _):
                await self.sceneSessionStore.saveWindowSessionState(sceneID: sceneID, snapshot: snapshot)
                await self.sceneSessionStore.saveContinueBrowsingSummary(
                    sceneID: sceneID,
                    summary: Self.makeContinueBrowsingSummary(sceneID: sceneID, snapshot: snapshot)
                )
            case .memory:
                self.memorySnapshot = snapshot
            }
        }
    }

    // MARK: - Durable Navigation (Safari-grade)

    @MainActor
    public func navigationState(for tabID: UUID?) -> TabNavigationState? {
        guard let tabID else { return nil }
        return tabNavigationByID[tabID]
    }

    @MainActor
    public func canGoBack(tabID: UUID?) -> Bool {
        navigationState(for: tabID)?.canGoBack ?? false
    }

    @MainActor
    public func canGoForward(tabID: UUID?) -> Bool {
        navigationState(for: tabID)?.canGoForward ?? false
    }

    /// Records a user intent to go back/forward to an existing history entry.
    ///
    /// Returns the target URL string if available.
    @MainActor
    public func requestGoToHistoryIndex(tabID: UUID, index: Int) -> String? {
        guard var state = tabNavigationByID[tabID] else { return nil }
        guard let entry = state.entry(at: index) else { return nil }
        state = TabNavigationReducer.reduce(state, event: .userRequestedGoToIndex(index))
        tabNavigationByID[tabID] = state
        scheduleSave()
        return entry.urlString
    }

    @MainActor
    public func requestGoBack(tabID: UUID) -> String? {
        guard let state = tabNavigationByID[tabID],
              let cursor = state.cursor else { return nil }
        return requestGoToHistoryIndex(tabID: tabID, index: cursor.index - 1)
    }

    @MainActor
    public func requestGoForward(tabID: UUID) -> String? {
        guard let state = tabNavigationByID[tabID],
              let cursor = state.cursor else { return nil }
        return requestGoToHistoryIndex(tabID: tabID, index: cursor.index + 1)
    }

    @MainActor
    public func applyWebKitCommit(tabID: UUID, context: TabNavigationCommitContext) {
        let current = tabNavigationByID[tabID] ?? Self.makeInitialNavigationState(from: tabs.first(where: { $0.id == tabID }))
        let next = TabNavigationReducer.reduce(current, event: .webKitDidCommit(context))
        tabNavigationByID[tabID] = next
        scheduleSave()
    }

    @MainActor
    public func recordUserRequestedLoad(tabID: UUID, urlString: String, replaceCurrent: Bool) {
        var state = tabNavigationByID[tabID] ?? Self.makeInitialNavigationState(from: tabs.first(where: { $0.id == tabID }))
        let event: TabNavigationEvent = replaceCurrent ? .userRequestedReplaceWithURLString(urlString) : .userRequestedLoadURLString(urlString)
        state = TabNavigationReducer.reduce(state, event: event)
        tabNavigationByID[tabID] = state
        scheduleSave()
    }

    @MainActor
    public func resetToSingleNewTab() {
        let tab = BrowserTab()
        tabs = [tab]
        selectedTabID = tab.id
        tabGroups = []
        selectedTabGroupID = nil
        recentlyClosed = []
        splitViewState = .init()
        uiState = .init()
        tabNavigationByID = [tab.id: Self.makeInitialNavigationState(from: tab)]
        saveNow()
    }

    @MainActor
    private func ensureNavigationStateConsistency() {
        let validIDs = Set(tabs.map { $0.id })

        // Drop orphan navigation state.
        for id in tabNavigationByID.keys where !validIDs.contains(id) {
            tabNavigationByID[id] = nil
        }

        // Seed missing navigation state.
        for tab in tabs where tabNavigationByID[tab.id] == nil {
            tabNavigationByID[tab.id] = Self.makeInitialNavigationState(from: tab)
        }
    }

    private static func makeInitialNavigationState(from tab: BrowserTab?) -> TabNavigationState {
        guard let tab else { return TabNavigationState() }
        let trimmed = tab.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return TabNavigationState() }
        if trimmed.lowercased() == "about:blank" { return TabNavigationState() }
        return TabNavigationState(entries: [NavigationEntry(urlString: trimmed, title: tab.title)], cursor: .init(index: 0))
    }

    // MARK: - Tab reordering
    public func moveTab(from: Int, to: Int) {
        guard from != to else { return }
        guard tabs.indices.contains(from) else { return }

        let item = tabs[from]
        let pinnedCount = tabs.reduce(0) { $0 + ($1.isPinned ? 1 : 0) }

        // Constrain reorders within pinned or unpinned segment.
        let allowedRange: Range<Int> = item.isPinned
            ? 0..<max(1, pinnedCount)
            : pinnedCount..<max(pinnedCount + 1, tabs.count)

        let clampedTo = max(allowedRange.lowerBound, min(to, allowedRange.upperBound - 1))
        guard tabs.indices.contains(clampedTo) else { return }

        let removed = tabs.remove(at: from)
        let adjustedTo = (from < clampedTo) ? (clampedTo - 1) : clampedTo
        tabs.insert(removed, at: adjustedTo)
        normalizeTabStateConsistency()
        persist()
    }

}
