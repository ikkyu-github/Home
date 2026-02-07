import Foundation
import os
import SafariLikeCoreKit
import SafariLikeContracts
import WebKit

/// @MainActor ที่จัดการ plugin lifecycle สำหรับแต่ละ window/scene
///
/// ดีไซน์ใหม่: **iOS-safe, compile-time plugins เท่านั้น**
/// - ไม่โหลดโค้ดจากไฟล์ภายนอกที่ runtime
/// - ใช้ `CompileTimePluginRegistry` map จาก `manifest.id` → plugin factory
/// - ใช้ `PluginEnablementStore` เก็บ enabled/disabled state
@MainActor
final class PluginHost {
    static let logger = Logger(subsystem: "SafariLikeKit", category: "PluginHost")

    /// Best-effort hook timeout for plugin lifecycle hooks.
    static let hookTimeoutNanoseconds: UInt64 = 200_000_000 // 200ms

    let windowID: String
    let tabID: String

    weak var sessionProvider: PluginSessionProvider?
    let normalSessionStore: BrowserSessionStore
    let privateSessionStore: BrowserSessionStore
    let libraryRepository: any LibraryRepository
    let enablementStore: PluginEnablementStore
    let webContextManager: WebContextManager

    var pluginManagers: [String: NextGenPluginManager] = [:]

    /// Window-scoped runtime plugin registry.
    ///
    /// Source of truth for installed/enabled swift plugins.
    let pluginRegistry = RuntimePluginRegistry()

    // MARK: - Resource Plugins
    let resourceLoader = ResourcePluginLoader()
    let resourceApplier = ResourcePluginApplier()

    /// Cached resolved resource plugins on disk.
    var cachedResourcePackages: [ResourcePluginPackage] = []
    /// Cached enabled plugin IDs for this window.
    var cachedEnabledPluginIDs: Set<String> = []
    /// Cached granted permissions per plugin ID for this window.
    ///
    /// This cache is used for resource-plugin application (which must be sync).
    var cachedGrantedPermissionsByPluginID: [String: Set<PluginPermission>] = [:]

    var enablementObserver: Any?

    /// Marker to ensure resource plugins are applied only once per `WKWebViewConfiguration`.
    static var resourceAppliedAssociationKey: UInt8 = 0

    /// Failure counter used by the simple navigation plugin API.
    var errorCounts: [String: Int] = [:]

    /// Initializes PluginHost for a specific window and tab
    /// - Parameters:
    ///   - windowID: Window identifier (UUID.uuidString recommended)
    ///   - tabID: Tab identifier (UUID.uuidString recommended)
    ///   - enablementStore: Store for managing enabled/disabled plugin state
    init(
        windowID: String,
        tabID: String,
        webContextManager: WebContextManager,
        enablementStore: PluginEnablementStore,
        normalSessionStore: BrowserSessionStore,
        privateSessionStore: BrowserSessionStore,
        libraryRepository: any LibraryRepository,
        sessionProvider: PluginSessionProvider? = nil
    ) {
        self.windowID = windowID
        self.tabID = tabID
        self.webContextManager = webContextManager
        self.enablementStore = enablementStore
        self.sessionProvider = sessionProvider
        self.normalSessionStore = normalSessionStore
        self.privateSessionStore = privateSessionStore
        self.libraryRepository = libraryRepository

        // Create initial per-tab manager so NavigationService can resolve immediately.
        self.pluginManagers[tabID] = NextGenPluginManager(tabID: tabID, host: self)

        // Apply resource plugins at the moment a new WKWebViewConfiguration is created
        // for this window's web contexts.
        webContextManager.setConfigurationCustomizer(for: windowID) { [weak self] configuration in
            guard let self else { return }
            self.applyResourcePluginsIfNeeded(to: configuration)
        }

        // Keep resource plugin caches up-to-date when enablement or permissions change.
        enablementObserver = NotificationCenter.default.addObserver(
            forName: PluginEnablementStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard (note.userInfo?["windowID"] as? String) == self.windowID else { return }
            Task { @MainActor in
                await self.refreshResourcePluginCache()
            }
        }

        // Best-effort: prime caches.
        Task { @MainActor in
            await self.refreshResourcePluginCache()
        }
    }
}
