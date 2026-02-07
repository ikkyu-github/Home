import Foundation
import Combine
import BrowserCore

/// Canonical, window-scoped source of truth for UI-observable state.
///
/// Safari principle: UI observes state; state does not live in UI.
@MainActor
public final class WindowSession: ObservableObject {

    // MARK: - Public state

    @Published public private(set) var activeTabID: UUID?
    @Published public private(set) var tabGroups: [BrowserTabGroup]
    @Published public var sidebarMode: SidebarMode
    @Published public var browsingProfile: BrowsingProfile

    // MARK: - Backing store binding

    public private(set) var sessionStore: BrowserSessionStore
    private var storeCancellables = Set<AnyCancellable>()

    public init(
        sessionStore: BrowserSessionStore,
        sidebarMode: SidebarMode = .hidden,
        browsingProfile: BrowsingProfile = .regular
    ) {
        self.sessionStore = sessionStore
        self.activeTabID = sessionStore.selectedTabID
        self.tabGroups = sessionStore.tabGroups
        self.sidebarMode = sidebarMode
        self.browsingProfile = browsingProfile
        bind(to: sessionStore)
    }

    /// Rebinds the WindowSession to a different underlying session store.
    ///
    /// This is used when switching between regular/private profiles.
    public func bind(to store: BrowserSessionStore) {
        sessionStore = store
        storeCancellables.removeAll()

        store.$selectedTabID
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.activeTabID = $0 }
            .store(in: &storeCancellables)

        store.$tabGroups
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.tabGroups = $0 }
            .store(in: &storeCancellables)
    }
}
