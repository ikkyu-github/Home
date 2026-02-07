import Foundation
import Combine
import SafariLikeKit
import SafariLikeContracts
import SwiftUI
import UIKit

// MARK: - Phase 2: Composition + Bootstrap

@MainActor
enum BootstrapState: Equatable {
    case idle
    case bootstrapping
    case ready
    case failed(message: String)
}

/// App-scope composition root.
///
/// Owns shared services that must exist exactly once per process:
/// - WebsitePreferencesStore
/// - Bookmarks/History/ReadingList persistence
/// - AppLifecycleCoordinator
@MainActor
final class AppCompositionRoot: ObservableObject {
    @Published private(set) var bootstrapState: BootstrapState = .idle

    let lifecycleCoordinator: AppLifecycleCoordinator
    let crashGuard: CrashGuard
    let sceneMetrics: SceneMetrics
    let settings: AppSettings

    // Shared stores/services (app-scope)
    let websitePreferencesStore: any WebsitePreferencesProviding
    let downloadFileIO: any DownloadFileIO

    // App-scope window/session registry
    let appSessionController: AppBrowserSessionController

    private var bootstrapTask: Task<Void, Never>?

    init() {
        self.lifecycleCoordinator = AppLifecycleCoordinator()
        self.crashGuard = CrashGuard()
        self.sceneMetrics = SceneMetrics()
        self.settings = AppSettings()

        self.websitePreferencesStore = SafariLikeStores.makeWebsitePreferencesStore()
        self.downloadFileIO = DefaultDownloadFileIO()

        SafariLikeAppFacade.bootstrapSharedIfNeeded(
            websitePreferencesStore: websitePreferencesStore,
            downloadFileIO: downloadFileIO
        )

        self.appSessionController = AppBrowserSessionController(
            websitePreferencesStore: websitePreferencesStore,
            downloadFileIO: downloadFileIO
        )
    }

    func bootstrapIfNeeded() async {
        if case .ready = bootstrapState { return }
        if let bootstrapTask {
            await bootstrapTask.value
            return
        }

        bootstrapState = .bootstrapping

        let task = Task { @MainActor in
            await AppFirstFrameStartup(
                crashGuard: crashGuard,
                lifecycleCoordinator: lifecycleCoordinator
            ).run()
            bootstrapState = .ready
        }
        bootstrapTask = task
        await task.value
    }
}

/// Scene/window-scope composition root.
///
/// Owns per-scene runtime objects (must not be created by SwiftUI views):
/// - BrowserSceneSession
/// - per-scene thumbnail store
/// - per-window UI glue (RelatedChromeState)
@MainActor
final class SceneCompositionRoot: ObservableObject {
    @Published private(set) var bootstrapState: BootstrapState = .idle

    private unowned let appRoot: AppCompositionRoot
    private var bootstrapTask: Task<Void, Never>?
    private var didRegisterLifecycle: Bool = false

    let windowLifecycleCoordinator: LifecycleCoordinator

    // Identity (configured once per scene)
    private(set) var sceneID: String = ""
    private(set) var windowID: BrowserWindowID?

    // Scene-owned runtime
    private(set) var thumbnailStore: TabThumbnailStore
    @Published private(set) var session: BrowserSceneSession?
    @Published private(set) var runtimeContext: SceneRuntimeContext?

    // Scene UI state
    let relatedChrome = RelatedChromeState()

    init(appRoot: AppCompositionRoot) {
        self.appRoot = appRoot
        self.thumbnailStore = TabThumbnailStore()
        self.windowLifecycleCoordinator = LifecycleCoordinator(appLifecycle: appRoot.lifecycleCoordinator)
    }

    func configureIdentityIfNeeded(sceneID: String, windowID: BrowserWindowID, uiSceneSession: UISceneSession?) {
        if self.sceneID.isEmpty {
            self.sceneID = sceneID
            self.windowID = windowID
            appRoot.appSessionController.ensureWindow(id: windowID.value)
        }

        // Best-effort: UI scene session can arrive after identity was set.
        // Keep restoration metadata in sync without changing identity.
        if let uiSceneSession,
           let configuredWindowID = self.windowID,
           self.sceneID.isEmpty == false {
            let info: [String: Any] = [
                SceneRestorationKeys.browserWindowUUID: configuredWindowID.value.uuidString,
                SceneRestorationKeys.browserSceneID: self.sceneID
            ]
            uiSceneSession.userInfo = (uiSceneSession.userInfo ?? [:]).merging(info) { _, new in new }
        }
    }

    func bootstrapIfNeeded(configuration: SafariLikeConfiguration, openBlank: Bool) async {
        guard let windowID else { return }
        guard sceneID.isEmpty == false else { return }
        if case .ready = bootstrapState { return }
        if let bootstrapTask {
            await bootstrapTask.value
            return
        }

        bootstrapState = .bootstrapping

        let task = Task { @MainActor in
            // Safari-like: do not start heavy runtime work before first frame.
            LaunchLog.mark("SceneCompositionRoot.bootstrapIfNeeded.begin sceneID=\(sceneID)")
            await Task.yield()

            let created = appRoot.appSessionController.sceneSession(
                sceneID: sceneID,
                windowID: windowID.value,
                configuration: configuration,
                performAutoRestore: openBlank == false,
                thumbnailStore: thumbnailStore
            )
            self.session = created
            LaunchLog.mark("SceneCompositionRoot.bootstrapIfNeeded.sessionCreated sceneID=\(sceneID)")

            if openBlank {
                created.resetToSingleBlankTab()
            }

            bootstrapState = .ready
        }

        bootstrapTask = task
        await task.value
    }

    func registerLifecycleIfNeeded(scenePhase: ScenePhase, lifecycle: AppLifecycleCoordinator) {
        guard didRegisterLifecycle == false else { return }
        guard let session, let windowID else { return }
        guard sceneID.isEmpty == false else { return }

        windowLifecycleCoordinator.registerScene(
            sceneID: sceneID,
            windowID: windowID,
            session: session
        )

        runtimeContext = lifecycle.sceneRuntimeContext(for: SceneID(raw: sceneID))

        appRoot.appSessionController.markWindowActive(id: windowID.value)
        windowLifecycleCoordinator.handleAppEvent(.launch)
        windowLifecycleCoordinator.handleWindowEvent(sceneID: sceneID, event: .connect)

        switch scenePhase {
        case .active:
            windowLifecycleCoordinator.handleWindowEvent(sceneID: sceneID, event: .foreground)
            appRoot.appSessionController.markWindowActive(id: windowID.value)
        case .background, .inactive:
            windowLifecycleCoordinator.handleWindowEvent(sceneID: sceneID, event: .background)
        @unknown default:
            break
        }

        // Replay: cold-start timing safety.
        windowLifecycleCoordinator.handleBrowserRuntimeEvent(.rootViewAppeared, session: session)
        didRegisterLifecycle = true
    }

    func onScenePhaseChanged(_ newPhase: ScenePhase) {
        guard didRegisterLifecycle else { return }
        guard sceneID.isEmpty == false else { return }
        switch newPhase {
        case .active:
            windowLifecycleCoordinator.handleWindowEvent(sceneID: sceneID, event: .foreground)
            if let session {
                windowLifecycleCoordinator.handleBrowserRuntimeEvent(.rootViewAppeared, session: session)
            }
        case .background, .inactive:
            windowLifecycleCoordinator.handleWindowEvent(sceneID: sceneID, event: .background)
        @unknown default:
            break
        }
    }
}

@MainActor
final class AppBrowserSessionController: ObservableObject {
    @Published private(set) var activeWindowID: UUID?
    @Published private(set) var knownWindowIDs: Set<UUID>

    private let tabManager: TabManager
    private let facade: SafariLikeAppFacade

#if DEBUG
    convenience init() {
        let io = DefaultDownloadFileIO()
        self.init(
            websitePreferencesStore: SafariLikeStores.makeWebsitePreferencesStore(),
            downloadFileIO: io
        )
    }
#else
    @available(*, unavailable, message: "Use the injected init to avoid duplicated services/stores.")
    convenience init() {
        fatalError("unavailable")
    }
#endif

    init(
        websitePreferencesStore: any WebsitePreferencesProviding,
        downloadFileIO: any DownloadFileIO
    ) {
        let tabManager = TabManager()
        self.tabManager = tabManager
        SafariLikeAppFacade.bootstrapSharedIfNeeded(
            websitePreferencesStore: websitePreferencesStore,
            downloadFileIO: downloadFileIO
        )
        self.facade = SafariLikeAppFacade.shared
        self.activeWindowID = tabManager.activeWindowID
        self.knownWindowIDs = tabManager.knownWindowIDs
    }

    func ensureWindow(id: UUID) {
        tabManager.ensureWindow(id: id)
        syncPublishedState()
    }

    func markWindowActive(id: UUID) {
        tabManager.markWindowActive(id: id)
        syncPublishedState()
    }

    func sceneSession(
        sceneID: String,
        windowID: UUID,
        configuration: SafariLikeConfiguration,
        performAutoRestore: Bool,
        thumbnailStore: any ThumbnailCapturing
    ) -> BrowserSceneSession {
        facade.makeSceneSession(
            sceneID: sceneID,
            windowID: windowID,
            configuration: configuration,
            performAutoRestore: performAutoRestore,
            thumbnailStore: thumbnailStore
        )
    }

    func removeWindow(id: UUID) {
        tabManager.removeWindow(id: id)
        syncPublishedState()
    }

    private func syncPublishedState() {
        activeWindowID = tabManager.activeWindowID
        knownWindowIDs = tabManager.knownWindowIDs
    }
}

// MARK: - Delegates

@MainActor
private final class TabManager {
    private(set) var activeWindowID: UUID?
    private(set) var knownWindowIDs: Set<UUID> = []

    func ensureWindow(id: UUID) {
        knownWindowIDs.insert(id)
    }

    func markWindowActive(id: UUID) {
        activeWindowID = id
    }

    func removeWindow(id: UUID) {
        knownWindowIDs.remove(id)
        if activeWindowID == id {
            activeWindowID = nil
        }
    }
}
