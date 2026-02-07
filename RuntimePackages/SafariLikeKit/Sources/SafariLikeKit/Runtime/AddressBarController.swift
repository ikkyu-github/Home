import Foundation
import SafariLikeCoreKit
import Combine
import SafariLikeUXKit
// AddressBarStateMachine lives in SafariLikeKit/Runtime/AddressBar.
@MainActor
final class AddressBarController: ObservableObject {
    // MARK: - Dependencies
    private let navigation: NavigationHandling
    private let normalSessionStore: BrowserSessionStore
    private let historyStore: HistoryStore
    private let bookmarkStore: BookmarkStore
    private let readingListStore: ReadingListStore
    // MARK: - State (state machine is the source of truth)
    @Published var isAddressFocusedExternally: Bool = false {
        didSet {
            guard isAddressFocusedExternally != oldValue else { return }
            guard !isSyncingFromStateMachine else { return }
            stateMachine.reduce(isAddressFocusedExternally ? .focusGained : .focusLost)
            syncFromStateMachine()
        }
    }
    @Published private(set) var suggestions: [SplitBrowserViewModel.OmniboxSuggestion] = []
    @Published private(set) var displayedText: String = ""
    @Published var draftText: String = ""
    @Published private(set) var shouldSelectAllOnFocus: Bool = false
    private var stateMachine: AddressBarEntryStateMachine<SplitBrowserViewModel.OmniboxSuggestion>
    private var stateMachineCancellables = Set<AnyCancellable>()
    private var isSyncingFromStateMachine: Bool = false
    @Published private(set) var isSubmitLocked: Bool = false
    private var submitLockTask: Task<Void, Never>?
    private let suggestionEngine = OmniboxSuggestionEngine()
    // Draft snapshot for UI domains still reading addressText.
    // Kept for backward compatibility; prefer displayedText/draftText.
    @Published var addressText: String = "" {
        didSet {
            guard !isSyncingFromStateMachine else { return }
            // Legacy binding surface:
            // - If focused, treat it as user typing.
            // - If not focused, treat it as a committed navigation value.
            stateMachine.reduce(isAddressFocusedExternally ? .userTyped(addressText) : .navigationCommitted(addressText))
            syncFromStateMachine()
        }
    }
    // MARK: - Callbacks into VM
    var onCollapseReset: (() -> Void)?
    init(
        navigation: NavigationHandling,
        normalSessionStore: BrowserSessionStore,
        historyStore: HistoryStore,
        bookmarkStore: BookmarkStore,
        readingListStore: ReadingListStore
    ) {
        self.navigation = navigation
        self.normalSessionStore = normalSessionStore
        self.historyStore = historyStore
        self.bookmarkStore = bookmarkStore
        self.readingListStore = readingListStore
        self.stateMachine = AddressBarEntryStateMachine<SplitBrowserViewModel.OmniboxSuggestion>(
            initialDisplayed: "",
            suggest: { _ in [] },
            onSubmit: { _ in }
        )
        bindStateMachine()
    }
    deinit {
        submitLockTask?.cancel()
    }
    // MARK: - Wiring
    /// Must be called once after init to configure callbacks (avoids self capture in init).
    func configureStateMachine(initialDisplayed: String) {
        // Recreate state machine with real callbacks.
        let suggestImpl: @MainActor @Sendable (String) async -> [SplitBrowserViewModel.OmniboxSuggestion] = { [weak self] query in
            guard let self else { return [] }
            // Snapshot data on MainActor to avoid races.
            let historySnapshot = self.historyStore.items.map {
                OmniboxSuggestionEngine.HistoryItemSnapshot(title: $0.title, urlString: $0.urlString, visitedAt: $0.visitedAt)
            }
            let bookmarkSnapshot = self.bookmarkStore.items.map {
                OmniboxSuggestionEngine.BookmarkSnapshot(
                    title: $0.title,
                    urlString: $0.urlString,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            }
            let readingListSnapshot = self.readingListStore.items.map {
                OmniboxSuggestionEngine.ReadingListItemSnapshot(title: $0.title, urlString: $0.urlString)
            }
            return await self.suggestionEngine.compute(
                query: query,
                historyItems: historySnapshot,
                bookmarkItems: bookmarkSnapshot,
                readingListItems: readingListSnapshot
            )
        }
        let submitImpl: @MainActor @Sendable (String) -> Void = { [weak self] text in
            guard let self else { return }
            // Use the existing controller path to preserve session store sync + submit lock.
            self.openURLString(text, force: false)
        }
        // Note: AddressBarStateMachine holds the debounce task; we just mirror its outputs.
        let sm = AddressBarEntryStateMachine<SplitBrowserViewModel.OmniboxSuggestion>(
            initialDisplayed: initialDisplayed,
            suggest: suggestImpl,
            onSubmit: submitImpl
        )
        stateMachine = sm
        bindStateMachine()
        // Seed state.
        stateMachine.reduce(.navigationCommitted(initialDisplayed))
        syncFromStateMachine()
    }
    private func bindStateMachine() {
        stateMachineCancellables.removeAll()
        stateMachine.$displayedText
            .removeDuplicates()
            .sink { [weak self] _ in self?.syncFromStateMachine() }
            .store(in: &stateMachineCancellables)
        stateMachine.$draftText
            .removeDuplicates()
            .sink { [weak self] _ in self?.syncFromStateMachine() }
            .store(in: &stateMachineCancellables)
        stateMachine.$shouldSelectAllOnFocus
            .removeDuplicates()
            .sink { [weak self] _ in self?.syncFromStateMachine() }
            .store(in: &stateMachineCancellables)
        stateMachine.$suggestions
            .sink { [weak self] _ in self?.syncFromStateMachine() }
            .store(in: &stateMachineCancellables)
        stateMachine.$mode
            .removeDuplicates()
            .sink { [weak self] _ in self?.syncFromStateMachine() }
            .store(in: &stateMachineCancellables)
    }
    private func withSubmitLock(_ body: () -> Void) {
        guard isSubmitLocked == false else { return }
        isSubmitLocked = true
        submitLockTask?.cancel()
        submitLockTask = Task { @MainActor [weak self] in
            // Short lock to prevent rapid double-submit.
            try? await Task.sleep(nanoseconds: 350_000_000)
            self?.isSubmitLocked = false
        }
        body()
    }
    // MARK: - Intents (Adapter)
    func requestAddressFocus() { requestFocus() }
    func requestFocus() {
        if !isAddressFocusedExternally {
            isAddressFocusedExternally = true
        }
        // focus gained is driven by isAddressFocusedExternally didSet
    }
    func userTyped(_ text: String) {
        stateMachine.reduce(.userTyped(text))
        syncFromStateMachine()
    }
    func submit() {
        guard isSubmitLocked == false else { return }
        stateMachine.reduce(.submit)
        syncFromStateMachine()
    }
    func cancel() {
        stateMachine.reduce(.cancel)
        syncFromStateMachine()
        isAddressFocusedExternally = false
    }
    func onNavigationCommitted(urlString: String) {
        stateMachine.reduce(.navigationCommitted(urlString))
        syncFromStateMachine()
    }
    func onTabChanged(urlString: String?) {
        stateMachine.reduce(.tabChanged(urlString))
        syncFromStateMachine()
    }
    func commitAddress() { submit() }
    func openExternalURL(_ url: URL) {
        withSubmitLock {
            let urlString = url.absoluteString
            addressText = urlString
            guard let activeTabID = normalSessionStore.selectedTabID else { return }
            normalSessionStore.updateTab(id: activeTabID, urlString: urlString)
            navigation.loadURLString(urlString, force: true)
            isAddressFocusedExternally = false
            onCollapseReset?()
            stateMachine.reduce(.navigationCommitted(urlString))
            syncFromStateMachine()
        }
    }
    func openURLString(_ urlString: String, force: Bool = false) {
        let normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        withSubmitLock {
            addressText = normalized
            guard let activeTabID = normalSessionStore.selectedTabID else { return }
            normalSessionStore.updateTab(id: activeTabID, urlString: normalized)
            navigation.loadURLString(normalized, force: force)
            isAddressFocusedExternally = false
            onCollapseReset?()
            stateMachine.reduce(.navigationCommitted(normalized))
            syncFromStateMachine()
        }
    }
    func loadSearch(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        withSubmitLock {
            // Delegate to NavigationService via protocol; underlying TabWebStore
            // will normalize and route this as a search query.
            navigation.loadURLString(q, force: false)
            isAddressFocusedExternally = false
            onCollapseReset?()
            stateMachine.reduce(.navigationCommitted(q))
            syncFromStateMachine()
        }
    }
    func updateSuggestions(query: String) { userTyped(query) }
    func clearSuggestions() {
        stateMachine.reduce(.userTyped(""))
        syncFromStateMachine()
    }
    func applySuggestion(_ suggestion: SplitBrowserViewModel.OmniboxSuggestion) {
        if let url = suggestion.urlString {
            openURLString(url, force: false)
        } else if let q = suggestion.query {
            loadSearch(query: q)
        }
    }
    private func syncFromStateMachine() {
        isSyncingFromStateMachine = true
        displayedText = stateMachine.displayedText
        draftText = stateMachine.draftText
        shouldSelectAllOnFocus = stateMachine.shouldSelectAllOnFocus
        suggestions = stateMachine.suggestions
        // Keep legacy addressText mirror consistent for existing bindings.
        addressText = (stateMachine.mode == .editing) ? stateMachine.draftText : stateMachine.displayedText
        isSyncingFromStateMachine = false
    }
}
