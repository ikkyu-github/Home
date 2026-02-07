import Foundation
import SafariLikeContracts
import SafariLikeCoreKit
// MARK: - Architecture Boundary: Environment Dependencies
// BrowserEnvironment exposes only protocol-typed dependencies for core services
// (WebsitePreferencesProviding, DownloadProviding, ThumbnailCapturing).
// Concrete implementations such as SafariLikeUIKit.WebsitePreferencesStore and
// SafariLikeUIKit.TabThumbnailStore are created in composition roots
// (e.g. SafariLikeFactory, BrowserSessionProvider, SafariLikeUIKitFactory)
// and passed in via these protocol boundaries.
@MainActor
struct BrowserEnvironment {
    /// Unique identifier for the owning scene/window.
    /// Typically backed by UISceneSession.persistentIdentifier.
    let sceneID: String
    /// Stable browser window identity.
    ///
    /// When present, this should map 1:1 with a `BrowserCore.BrowserWindow.id`.
    /// If absent, the environment falls back to using `sceneID` as the window identity.
    let windowID: UUID?
    /// Identity string used for window-scoped runtime objects (pools, registries, plugin enablement).
    var windowIdentityString: String { windowID?.uuidString ?? sceneID }
    let sessionStore: BrowserSessionStore
    let libraryProfileBox: BrowsingProfileBox
    let bookmarkStore: BookmarkStore
    let historyStore: HistoryStore
    let readingListStore: ReadingListStore
    // Core-facing website preferences store.
    // Implementation example: SafariLikeUIKit.WebsitePreferencesStore
    // via dependency injection from the app or UIKit host layer.
    let websitePreferencesStore: WebsitePreferencesProviding
    /// Process-wide per-site permissions/settings store.
    ///
    /// This must be shared across all windows/scenes to match Safari behavior.
    let siteSettingsStore: SiteSettingsStore
    // Download management interface (protocol-based boundary).
    let downloadStore: any DownloadProviding
    // UI/runtime thumbnail management interface (protocol-based boundary).
    let thumbnailStore: any ThumbnailCapturing
    let websiteDataService: any WebsiteDataServicing
    let privacyReportSnapshotStore: PrivacyReportSnapshotStore
    let formFillPolicyEngine: FormFillPolicyEngine
    let autofillStatusService: AutofillStatusService
    let userScriptStore: UserScriptStore
    let configuration: SafariLikeConfiguration
    // MARK: - Live (Production)
    static func live(
        sceneID: String,
        windowID: UUID? = nil,
        sessionStore: BrowserSessionStore,
        libraryProfileBox: BrowsingProfileBox,
        bookmarkStore: BookmarkStore,
        historyStore: HistoryStore,
        readingListStore: ReadingListStore,
        websitePreferencesStore: WebsitePreferencesProviding,
        siteSettingsStore: SiteSettingsStore,
        downloadStore: any DownloadProviding,
        thumbnailStore: any ThumbnailCapturing,
        websiteDataService: any WebsiteDataServicing,
        privacyReportSnapshotStore: PrivacyReportSnapshotStore,
        formFillPolicyEngine: FormFillPolicyEngine,
        autofillStatusService: AutofillStatusService,
        userScriptStore: UserScriptStore,
        configuration: SafariLikeConfiguration
    ) -> BrowserEnvironment {
        BrowserEnvironment(
            sceneID: sceneID,
            windowID: windowID,
            sessionStore: sessionStore,
            libraryProfileBox: libraryProfileBox,
            bookmarkStore: bookmarkStore,
            historyStore: historyStore,
            readingListStore: readingListStore,
            websitePreferencesStore: websitePreferencesStore,
            siteSettingsStore: siteSettingsStore,
            downloadStore: downloadStore,
            thumbnailStore: thumbnailStore,
            websiteDataService: websiteDataService,
            privacyReportSnapshotStore: privacyReportSnapshotStore,
            formFillPolicyEngine: formFillPolicyEngine,
            autofillStatusService: autofillStatusService,
            userScriptStore: userScriptStore,
            configuration: configuration
        )
    }
    // MARK: - Preview (SwiftUI / Dev)
#if DEBUG
    @MainActor
    static var preview: BrowserEnvironment {
        let stores = LibraryStoreFactory.makeStores()
        let websitePreferencesStore = DefaultWebsitePreferencesStore()
        // TODO: Update preview to use proper mock objects once WebsitePreferencesStore
        // type is available. For now using NSObject placeholder.
        return BrowserEnvironment(
            sceneID: "preview-scene",
            windowID: UUID(),
            sessionStore: BrowserSessionStore(persistence: .memory),
            libraryProfileBox: stores.profileBox,
            bookmarkStore: stores.bookmarks,
            historyStore: stores.history,
            readingListStore: stores.readingList,
            websitePreferencesStore: websitePreferencesStore,
            siteSettingsStore: SiteSettingsStore(persistence: .memory),
            downloadStore: NullDownloadStore(),
            thumbnailStore: PreviewThumbnailStore(),
            websiteDataService: CoreStoreFactory.makeWebsiteDataService(),
            privacyReportSnapshotStore: PrivacyReportSnapshotStore(persistence: .memory),
            formFillPolicyEngine: FormFillPolicyEngine(websitePreferencesStore: websitePreferencesStore),
            autofillStatusService: CoreStoreFactory.makeAutofillStatusService(),
            userScriptStore: CoreStoreFactory.makeUserScriptStore(),
            configuration: .default
        )
    }
#endif
    init(
        sceneID: String,
        windowID: UUID? = nil,
        sessionStore: BrowserSessionStore,
        libraryProfileBox: BrowsingProfileBox,
        bookmarkStore: BookmarkStore,
        historyStore: HistoryStore,
        readingListStore: ReadingListStore,
        websitePreferencesStore: WebsitePreferencesProviding,
        siteSettingsStore: SiteSettingsStore,
        downloadStore: any DownloadProviding,
        thumbnailStore: any ThumbnailCapturing,
        websiteDataService: any WebsiteDataServicing,
        privacyReportSnapshotStore: PrivacyReportSnapshotStore,
        formFillPolicyEngine: FormFillPolicyEngine,
        autofillStatusService: AutofillStatusService,
        userScriptStore: UserScriptStore,
        configuration: SafariLikeConfiguration
    ) {
        self.sceneID = sceneID
        self.windowID = windowID
        self.sessionStore = sessionStore
        self.libraryProfileBox = libraryProfileBox
        self.bookmarkStore = bookmarkStore
        self.historyStore = historyStore
        self.readingListStore = readingListStore
        self.websitePreferencesStore = websitePreferencesStore
        self.siteSettingsStore = siteSettingsStore
        self.downloadStore = downloadStore
        self.thumbnailStore = thumbnailStore
        self.websiteDataService = websiteDataService
        self.privacyReportSnapshotStore = privacyReportSnapshotStore
        self.formFillPolicyEngine = formFillPolicyEngine
        self.autofillStatusService = autofillStatusService
        self.userScriptStore = userScriptStore
        self.configuration = configuration
    }
}
