import Foundation
import SafariLikeContracts
import SafariLikeCoreKit
/// Factory for creating `BrowserSceneSession` instances.
///
/// `SafariLikeFactory` is the **core factory** for instantiating ``BrowserSceneSession``. Most UIKit
/// apps should use ``SafariLikeUIKitHost.makeHostingController(sceneID:initialURL:configuration:makeSettingsView:)``
/// instead, which calls this factory internally and returns both the session and a hosting controller.
///
/// For direct session creation or advanced use cases, use this factory directly.
///
/// ## Contract
/// - Call ``makeSceneSession(sceneID:configuration:)`` to create a session
/// - Pass the result to ``SafariLikeBrowserView`` or use its public facade methods
/// - Store and retain the session for the scene's lifetime
/// - **Never** access internal properties like `.viewModel` or `.chrome` outside SafariLikeKit
///
/// ## Typical Usage
/// ```swift
/// // Direct factory usage (less common)
/// let session = SafariLikeFactory.makeSceneSession(
///     sceneID: "main",
///     configuration: .default
/// )
/// ```
///
/// ```swift
/// // More common: use SafariLikeUIKitHost (UIKit)
/// let (hostVC, session) = SafariLikeUIKitHost.makeHostingController(
///     sceneID: "main",
///     initialURL: nil,
///     configuration: .default
/// )
/// ```
///
/// ## Related Types
/// - ``SafariLikeUIKitHost`` - Recommended for UIKit apps (returns hosting controller + session)
/// - ``BrowserSceneSession`` - The returned type; use only public methods
/// - ``SafariLikeConfiguration`` - Configuration passed to factory
@MainActor
public enum SafariLikeFactory {
    // SAFE SINGLETON (CACHED STATICS):
    // - Process-wide persistence stores (site settings, privacy snapshot).
    // - Must NOT store per-window/scene/tab runtime state.
    // Process-wide stores
    private static let sharedSiteSettingsStore = SiteSettingsStore(persistence: .default)
    private static var didBootstrapSiteSettingsStore = false

    private static let sharedPrivacyReportSnapshotStore = PrivacyReportSnapshotStore()
    private static var didBootstrapPrivacyReportSnapshotStore = false

    // Downloads are injected from the composition root (app / UIKit host).
    // Defaulting to a null implementation keeps SafariLikeKit cycle-free.

    @MainActor
    private static func ensureSiteSettingsStoreBootstrapped() {
        guard didBootstrapSiteSettingsStore == false else { return }
        didBootstrapSiteSettingsStore = true
        Task {
            await sharedSiteSettingsStore.bootstrap()
        }
    }

    @MainActor
    private static func ensurePrivacyReportSnapshotStoreBootstrapped() {
        guard didBootstrapPrivacyReportSnapshotStore == false else { return }
        didBootstrapPrivacyReportSnapshotStore = true
        Task {
            await sharedPrivacyReportSnapshotStore.bootstrap()
        }
    }

    /// Create a new browser session for a specific BrowserWindow.
    ///
    /// Use this overload in multi-window apps where:
    /// - 1 window = 1 `BrowserCore.BrowserWindow` (UUID)
    /// - Each window must restore its own tab stack
    /// - Window identity must not depend on SwiftUI view lifecycles
    public static func makeSceneSession(
        sceneID: String,
        windowID: UUID,
        configuration: SafariLikeConfiguration = .default,
        performAutoRestore: Bool = false,
        websitePreferencesStore: WebsitePreferencesProviding? = nil,
        siteSettingsStore: SiteSettingsStore? = nil,
        downloadStore: (any DownloadProviding)? = nil
    ) -> BrowserSceneSession {
        makeSceneSession(
            sceneID: sceneID,
            windowID: windowID,
            configuration: configuration,
            performAutoRestore: performAutoRestore,
            thumbnailStore: TabThumbnailStore(),
            websitePreferencesStore: websitePreferencesStore,
            siteSettingsStore: siteSettingsStore,
            downloadStore: downloadStore
        )
    }
    /// Create a new browser session for a specific BrowserWindow with an injected thumbnail store.
    public static func makeSceneSession(
        sceneID: String,
        windowID: UUID,
        configuration: SafariLikeConfiguration = .default,
        performAutoRestore: Bool = false,
        thumbnailStore: any ThumbnailCapturing,
        websitePreferencesStore: WebsitePreferencesProviding? = nil,
        siteSettingsStore: SiteSettingsStore? = nil,
        downloadStore: (any DownloadProviding)? = nil
    ) -> BrowserSceneSession {
        ensureSiteSettingsStoreBootstrapped()
        ensurePrivacyReportSnapshotStoreBootstrapped()
        let libraryStores = LibraryStoreFactory.makeStores()
        let resolvedSiteSettingsStore = siteSettingsStore ?? sharedSiteSettingsStore
        let resolvedWebsitePreferencesStore = websitePreferencesStore ?? CoreStoreFactory.makeWebsitePreferencesStore()

        let resolvedDownloadStore: any DownloadProviding = downloadStore ?? NullDownloadStore()
        let environment = BrowserEnvironment(
            sceneID: sceneID,
            windowID: windowID,
            // One BrowserSessionStore per browser window. This ensures each
            // BrowserWindow restores its own tabs and active selection.
            sessionStore: CoreStoreFactory.makeWindowSessionStore(windowID: windowID),
            libraryProfileBox: libraryStores.profileBox,
            bookmarkStore: libraryStores.bookmarks,
            historyStore: libraryStores.history,
            readingListStore: libraryStores.readingList,
            websitePreferencesStore: resolvedWebsitePreferencesStore,
            siteSettingsStore: resolvedSiteSettingsStore,
            downloadStore: resolvedDownloadStore,
            thumbnailStore: thumbnailStore,
            websiteDataService: CoreStoreFactory.makeWebsiteDataService(),
            privacyReportSnapshotStore: sharedPrivacyReportSnapshotStore,
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
        let session = BrowserSceneSession(environment: environment)
        if performAutoRestore {
            Task { @MainActor in
                await session.restoreInitialPersistedStateIfAvailable()
            }
        }
        return session
    }
    /// Create a new browser session using SafariLikeKit's default runtime components.
    ///
    /// This overload exists so the app target does not need to depend on internal modules
    /// to provide a thumbnail store implementation.
    public static func makeSceneSession(
        sceneID: String,
        configuration: SafariLikeConfiguration = .default,
        performAutoRestore: Bool = false,
        websitePreferencesStore: WebsitePreferencesProviding? = nil,
        siteSettingsStore: SiteSettingsStore? = nil,
        downloadStore: (any DownloadProviding)? = nil
    ) -> BrowserSceneSession {
        makeSceneSession(
            sceneID: sceneID,
            configuration: configuration,
            performAutoRestore: performAutoRestore,
            thumbnailStore: TabThumbnailStore(),
            websitePreferencesStore: websitePreferencesStore,
            siteSettingsStore: siteSettingsStore,
            downloadStore: downloadStore
        )
    }
    /// Create a new browser session with the given configuration.
    ///
    /// - Parameters:
    ///   - sceneID: Unique identifier for this scene (used for persistence and debugging)
    ///   - configuration: Browser configuration (defaults to ``SafariLikeConfiguration.default``)
    ///
    /// - Returns: A new `BrowserSceneSession` ready to use
    ///
    /// ## Semantics
    /// Each call creates a fresh session with:
    /// - New session store (loads persisted tabs if available)
    /// - New ViewModels and UI state
    /// - New WebKit runtime (but reuses shared website data store if configured)
    ///
    /// The session is independent; you can create multiple sessions if needed.
    /// However, most apps create one session per scene.
    public static func makeSceneSession(
        sceneID: String,
        configuration: SafariLikeConfiguration = .default,
        performAutoRestore: Bool = false,
        thumbnailStore: any ThumbnailCapturing,
        websitePreferencesStore: WebsitePreferencesProviding? = nil,
        siteSettingsStore: SiteSettingsStore? = nil,
        downloadStore: (any DownloadProviding)? = nil
    ) -> BrowserSceneSession {
        ensureSiteSettingsStoreBootstrapped()
        ensurePrivacyReportSnapshotStoreBootstrapped()
        let libraryStores = LibraryStoreFactory.makeStores()
        let resolvedSiteSettingsStore = siteSettingsStore ?? sharedSiteSettingsStore
        let resolvedWebsitePreferencesStore = websitePreferencesStore ?? CoreStoreFactory.makeWebsitePreferencesStore()

        let resolvedDownloadStore: any DownloadProviding = downloadStore ?? NullDownloadStore()
        let environment = BrowserEnvironment(
            sceneID: sceneID,
            // One BrowserSessionStore per scene/window. This ensures each
            // window restores its own tabs and active selection, matching
            // Safari-style multi-window behavior.
            sessionStore: CoreStoreFactory.makeWindowSessionStore(sceneID: sceneID),
            libraryProfileBox: libraryStores.profileBox,
            bookmarkStore: libraryStores.bookmarks,
            historyStore: libraryStores.history,
            readingListStore: libraryStores.readingList,
            websitePreferencesStore: resolvedWebsitePreferencesStore,
            siteSettingsStore: resolvedSiteSettingsStore,
            downloadStore: resolvedDownloadStore,
            thumbnailStore: thumbnailStore,
            websiteDataService: CoreStoreFactory.makeWebsiteDataService(),
            privacyReportSnapshotStore: sharedPrivacyReportSnapshotStore,
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
        let session = BrowserSceneSession(environment: environment)
        if performAutoRestore {
            Task { @MainActor in
                await session.restoreInitialPersistedStateIfAvailable()
            }
        }
        return session
    }
}
