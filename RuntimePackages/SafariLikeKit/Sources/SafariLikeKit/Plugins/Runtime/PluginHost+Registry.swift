import Foundation
import SafariLikeCoreKit
import SafariLikeContracts

// MARK: - Next-gen plugin manager (minimal stub)
//
// NavigationService currently expects a per-tab manager used for an interception pipeline.
// The compile-time plugin system in SafariLikeKit uses PluginContext + PluginSessionProvider
// for interception and eventing. Until a dedicated next-gen runtime exists, this manager is
// intentionally minimal and side-effect free.
@MainActor
final class NextGenPluginManager {
    let tabID: String
    private unowned let host: PluginHost
    init(tabID: String, host: PluginHost) {
        self.tabID = tabID
        self.host = host
    }
    func willLoadURL(_ request: NavigationRequest) async -> InterceptionResponse {
        _ = host
        _ = request
        return .allow
    }
    func didLoadURL(_ request: NavigationRequest) async {
        _ = host
        _ = request
    }
}

extension PluginHost {
    // MARK: - Next-gen plugin manager (NavigationService)

    /// NavigationService expects a per-tab manager object (even if it's currently a no-op).
    func getOrCreatePluginManager(for tabID: String) -> NextGenPluginManager {
        if let existing = pluginManagers[tabID] {
            return existing
        }
        let created = NextGenPluginManager(tabID: tabID, host: self)
        pluginManagers[tabID] = created
        return created
    }

    // MARK: - Install / enablement

    func loadInstalledPlugins() async {
        // 1) Snapshot enablement + permissions first.
        let enabledIDs = Set(await enablementStore.getEnabledPlugins())
        let grantedPermissionsByPluginID = await enablementStore.getGrantedPermissionsByPluginID()

        // 2) Install all compile-time plugins (deterministic order).
        let allIDs = CompileTimePluginRegistry.allKnownPluginIDs().sorted()
        for pluginID in allIDs {
            guard let plugin = CompileTimePluginRegistry.resolve(id: pluginID) else {
                continue
            }
            let granted = grantedPermissionsByPluginID[pluginID] ?? []
            let context = makePluginContext(
                pluginID: pluginID,
                pluginCapabilities: plugin.capabilities,
                grantedPermissions: granted
            )
            await pluginRegistry.install(plugin, context: context)
        }

        // 3) Enable enabled plugins.
        // RuntimePluginRegistry guards idempotency.
        for pluginID in enabledIDs.sorted() {
            await pluginRegistry.enable(pluginID: pluginID)
        }

        // 4) Prime resource plugin caches (sync path for WebKit config customizer).
        await refreshResourcePluginCache()
    }

    func enablePlugin(id: String) async {
        await enablementStore.setEnabled(true, for: id)
        await pluginRegistry.enable(pluginID: id)
        await refreshResourcePluginCache()
    }

    func disablePlugin(id: String) async {
        await enablementStore.setEnabled(false, for: id)
        pluginRegistry.disable(pluginID: id)
        await refreshResourcePluginCache()
    }

    func shouldAllowNavigation(_ request: URLRequest) async -> Bool {
        await pluginRegistry.shouldAllowNavigation(request)
    }

    // MARK: - Context

    private func makePluginContext(
        pluginID: String,
        pluginCapabilities: Set<PluginCapability>,
        grantedPermissions: Set<PluginPermission>
    ) -> PluginContext {
        let session = sessionProvider

        // Prefer the session provider for query services when available.
        let tabQueryService: TabQueryService = (session as? TabQueryService)
            ?? CoreSessionStoreTabQueryService(sessionStore: normalSessionStore)

        let profile: BrowsingProfile = (session?.getIsPrivateMode() == true) ? .private : .regular
        let historyQueryService: HistoryQueryService = (session as? HistoryQueryService)
            ?? CoreLibraryRepositoryHistoryQueryService(repository: libraryRepository, profile: profile)
        let bookmarksQueryService: BookmarksQueryService = (session as? BookmarksQueryService)
            ?? CoreLibraryRepositoryBookmarksQueryService(repository: libraryRepository, profile: profile)

        return PluginContext(
            pluginID: pluginID,
            windowID: windowID,
            tabID: tabID,
            capabilities: pluginCapabilities,
            grantedPermissions: grantedPermissions,
            auditHandler: nil,
            session: session,
            tabQueryService: tabQueryService,
            historyQueryService: historyQueryService,
            bookmarksQueryService: bookmarksQueryService
        )
    }
}
