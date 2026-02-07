import Foundation
import Combine
import CoreGraphics
import SafariLikeCoreKit
// MARK: - Domain State (Business Logic Layer)
/// Immutable domain state representing the browser's data model.
/// No UI concerns, no presentation logic.
@MainActor
protocol BrowserDomainState: AnyObject {
    // Tabs & Navigation
    var activeTabID: UUID? { get set }
    var tabs: [BrowserTab] { get }
    var activeStore: (any WebStoreProviding)? { get }
    // Session modes
    var isPrivateMode: Bool { get set }
    // Libraries
    var bookmarkStore: BookmarkStore { get }
    var historyStore: HistoryStore { get }
    var readingListStore: ReadingListStore { get }
    /// Download management interface. Concrete implementation is injected
    /// (typically `DownloadCenterAdapter` / `SceneDownloadStore`, backed by `BrowserCore.DownloadCenter`).
    var downloadStore: any DownloadProviding { get }
    // Navigation state
    var canGoBack: Bool { get }
    var canGoForward: Bool { get }
    var isLoading: Bool { get }
}
// MARK: - UI State (Presentation Layer)
/// Mutable UI state for view controllers/SwiftUI views.
/// Presentation state only (sidebar visibility, animations, etc.)
@MainActor
protocol BrowserUIState: AnyObject, ObservableObject {
    // Layout
    var isSidebarVisible: Bool { get set }
    var isTabOverviewVisible: Bool { get set }
    var isBottomBarCollapsed: Bool { get set }
    // Progress & Loading
    var pageProgress: Double { get set }
}
// MARK: - Coordinator (Navigation & Actions)
/// Handles navigation, user actions, and state mutations.
/// Acts as mediator between UI and Domain.
@MainActor
protocol BrowserCoordinator: AnyObject {
    associatedtype Domain: BrowserDomainState
    associatedtype UI: BrowserUIState
    var domain: Domain { get }
    var ui: UI { get }
    // Navigation actions
    func goBack()
    func goForward()
    func reload()
    func stopLoading()
    // Tab management
    func newTab()
    func closeTab(_ tabID: UUID)
    func selectTab(_ tabID: UUID)
    // URL loading
    func loadURL(_ url: URL)
    func loadURLString(_ string: String, force: Bool)
    // Session lifecycle
    func persistSessionNow()
    func invalidateSession()
}
// NOTE: Legacy plugin contracts removed.
// The new plugin system lives under SafariLikeKit/Plugins/Core.
