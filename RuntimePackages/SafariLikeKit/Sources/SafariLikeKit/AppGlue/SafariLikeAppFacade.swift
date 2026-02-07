import Foundation
import SafariLikeContracts
import SafariLikeCoreKit

/// App-facing facade that centralizes per-scene session creation and app/window lifecycle wiring.
///
/// Contract:
/// - App targets should depend on `SafariLikeKit` and call into this facade.
/// - App targets must not import `BrowserCore` / `SafariLikeCoreKit` / `SafariLikeUXKit` directly.
@MainActor
public final class SafariLikeAppFacade {
    private static var _shared: SafariLikeAppFacade?

    /// Process-wide shared app facade.
    ///
    /// Call `bootstrapSharedIfNeeded(websitePreferencesStore:downloadFileIO:)` before first use.
    ///
    /// SAFE SINGLETON:
    /// - Process-wide facade for app entrypoints into SafariLikeKit.
    /// - Stores app-level dependencies only; must NOT store per-scene/tab runtime state.
    @MainActor
    public static var shared: SafariLikeAppFacade {
        guard let instance = _shared else {
            preconditionFailure("SafariLikeAppFacade.shared used before bootstrapSharedIfNeeded")
        }
        return instance
    }

    /// Idempotently bootstraps the shared facade and its internal download center.
    @MainActor
    public static func bootstrapSharedIfNeeded(
        websitePreferencesStore: any WebsitePreferencesProviding,
        downloadFileIO: any DownloadFileIO
    ) {
        if _shared != nil { return }
        _shared = SafariLikeAppFacade(
            websitePreferencesStore: websitePreferencesStore,
            downloadFileIO: downloadFileIO
        )
    }

    private let websitePreferencesStore: any WebsitePreferencesProviding
    private let downloadFileIO: any DownloadFileIO
    private let downloadCenter: DownloadCenter

    public init(
        websitePreferencesStore: any WebsitePreferencesProviding,
        downloadFileIO: any DownloadFileIO
    ) {
        self.websitePreferencesStore = websitePreferencesStore
        self.downloadFileIO = downloadFileIO
        self.downloadCenter = DownloadCenter(fileIO: downloadFileIO)
    }

    public func installLaunchHooks(
        onFirstWebViewCreated: (@MainActor () -> Void)?,
        onAppInteractive: (@MainActor () -> Void)?
    ) {
        WebKitWarmupHooks.onFirstWebViewCreated = onFirstWebViewCreated
        AppBootstrap.onAppInteractive = {
            Task { @MainActor in
                onAppInteractive?()
            }
        }
    }

    public func makeSceneSession(
        sceneID: String,
        windowID: UUID,
        configuration: SafariLikeConfiguration,
        performAutoRestore: Bool,
        thumbnailStore: any ThumbnailCapturing
    ) -> BrowserSceneSession {
        let perSceneDownloadStore = SceneDownloadStore(
            center: downloadCenter,
            fileIO: downloadFileIO,
            sceneID: sceneID
        )

        return SafariLikeFactory.makeSceneSession(
            sceneID: sceneID,
            windowID: windowID,
            configuration: configuration,
            performAutoRestore: performAutoRestore,
            thumbnailStore: thumbnailStore,
            websitePreferencesStore: websitePreferencesStore,
            downloadStore: perSceneDownloadStore
        )
    }

    /// Bridges UIApplicationDelegate background URLSession events to BrowserCore's download coordinator.
    ///
    /// This keeps the App target architecture-clean: AppDelegate forwards into SafariLikeKit,
    /// and only SafariLikeKit touches BrowserCore APIs.
    public func handleBackgroundURLSession(
        identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        Task { [downloadCenter] in
            await downloadCenter.handleEventsForBackgroundURLSession(
                identifier: identifier,
                completionHandler: completionHandler
            )
        }
    }

    public func restoreIfNeeded(windowID: UUID) {
        #if DEBUG
        preconditionFailure("SafariLikeAppFacade.restoreIfNeeded(windowID:) is no longer supported. Own sessions per-scene and call restore on the session instance explicitly.")
        #else
        _ = windowID
        Diagnostics.logError(
            "[SafariLikeAppFacade] restoreIfNeeded(windowID:) is unsupported; own sessions per-scene and restore via the session instance.",
            subsystem: .runtime,
            category: "SceneIsolation"
        )
        #endif
    }

    public func removeWindow(windowID: UUID) {
        #if DEBUG
        preconditionFailure("SafariLikeAppFacade.removeWindow(windowID:) is no longer supported. Own sessions per-scene and invalidate via the session instance explicitly.")
        #else
        _ = windowID
        Diagnostics.logError(
            "[SafariLikeAppFacade] removeWindow(windowID:) is unsupported; own sessions per-scene and invalidate via the session instance.",
            subsystem: .runtime,
            category: "SceneIsolation"
        )
        #endif
    }
}
