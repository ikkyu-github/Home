import Foundation
import SafariLikeCoreKit

@MainActor
final class TabPluginController {
    private unowned let manager: TabManager

    init(manager: TabManager) {
        self.manager = manager
    }

    func start(initialActiveTabID: UUID) {
        manager.pluginHostTask = Task { @MainActor [weak manager] in
            guard let manager else { return }

            // SceneRuntimeContext owns window-scoped WebContextManager.
            // Wait until it is injected to avoid falling back to global caches.
            while manager.runtimeContextIfAvailable == nil {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
            }
            guard let runtimeContext = manager.runtimeContextIfAvailable else { return }

            await manager.enablementStore.loadEnablementState()
            manager.setPluginHost(
                PluginHost(
                windowID: manager.windowID,
                tabID: initialActiveTabID.uuidString,
                webContextManager: runtimeContext.webContextManager,
                enablementStore: manager.enablementStore,
                normalSessionStore: manager.normalSessionStore,
                privateSessionStore: manager.privateSessionStore,
                libraryRepository: LibraryStoreFactory.sharedRepository().0,
                sessionProvider: manager.pluginSessionProvider
                )
            )
            await manager.pluginHost?.loadInstalledPlugins()
        }
    }

    func shutdown() async {
        manager.pluginHostTask?.cancel()
        manager.pluginHostTask = nil

        await manager.pluginHost?.shutdown()
        manager.setPluginHost(nil)
    }

    func enablePlugin(id: String) async {
        await manager.pluginHost?.enablePlugin(id: id)
    }

    func disablePlugin(id: String) async {
        await manager.pluginHost?.disablePlugin(id: id)
    }
}
