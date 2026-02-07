import Foundation
import Combine
import SafariLikeCoreKit
// MARK: - Architecture: Thumbnail Store Injection
// Thumbnail store creation is injected from the UI composition root.
// This layer must not instantiate UIKit-owned concretes.
@MainActor
final class BrowserSessionProvider: ObservableObject {
    private let makeThumbnailStore: @MainActor () -> any ThumbnailCapturing
    private var sessions: [String: BrowserSceneSession] = [:]
    private let siteSettingsStore: SiteSettingsStore
    private let privacyReportSnapshotStore: PrivacyReportSnapshotStore
    private let downloadStore: any DownloadProviding
    init(
        makeThumbnailStore: @escaping @MainActor () -> any ThumbnailCapturing = { PreviewThumbnailStore() }
    ) {
        self.makeThumbnailStore = makeThumbnailStore
        let store = SiteSettingsStore(persistence: .default)
        self.siteSettingsStore = store
        self.privacyReportSnapshotStore = PrivacyReportSnapshotStore()
        self.downloadStore = NullDownloadStore()
        Task {
            await store.bootstrap()
            await self.privacyReportSnapshotStore.bootstrap()
        }
    }
    func session(
        sceneID: String,
        windowID: UUID? = nil,
        configuration: SafariLikeConfiguration
    ) -> BrowserSceneSession {
        let cacheKey = windowID?.uuidString ?? sceneID
        if let existing = sessions[cacheKey] {
            return existing
        }

        // One BrowserSessionStore per logical window so that each window
        // has its own tab list and active selection.
        let sessionStore: BrowserSessionStore = {
            if let windowID {
                return CoreStoreFactory.makeWindowSessionStore(windowID: windowID)
            }
            return CoreStoreFactory.makeWindowSessionStore(sceneID: sceneID)
        }()
        let libraryStores = LibraryStoreFactory.makeStores()
        let resolvedWebsitePreferencesStore = CoreStoreFactory.makeWebsitePreferencesStore()
        let environment = BrowserEnvironment(
            sceneID: sceneID,
            windowID: windowID,
            sessionStore: sessionStore,
            libraryProfileBox: libraryStores.profileBox,
            bookmarkStore: libraryStores.bookmarks,
            historyStore: libraryStores.history,
            readingListStore: libraryStores.readingList,
            websitePreferencesStore: resolvedWebsitePreferencesStore,
            siteSettingsStore: siteSettingsStore,
            downloadStore: downloadStore,
            thumbnailStore: makeThumbnailStore(),
            websiteDataService: CoreStoreFactory.makeWebsiteDataService(),
            privacyReportSnapshotStore: privacyReportSnapshotStore,
            formFillPolicyEngine: FormFillPolicyEngine(
                defaults: .init(
                    allowAutofill: { UserDefaults.standard.object(forKey: "app.autofill.enabled") as? Bool ?? true },
                    allowPasswordSaving: { true }
                ),
                websitePreferencesStore: resolvedWebsitePreferencesStore
            ),
            autofillStatusService: CoreStoreFactory.makeAutofillStatusService(),
            userScriptStore: CoreStoreFactory.makeUserScriptStore(),
            configuration: configuration
        )
        let newSession = BrowserSceneSession(environment: environment)
        sessions[cacheKey] = newSession
        return newSession
    }
}
