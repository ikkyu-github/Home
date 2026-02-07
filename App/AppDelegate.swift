import UIKit
import SafariLikeKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {

    // Injected from `SafariPadCloneApp` during app startup.
    @MainActor
    weak var appRoot: AppCompositionRoot?

    private var launchTraceID: PerformanceTracer.TraceID?

    private func startLaunchIfNeeded() {
        guard launchTraceID == nil else { return }
        launchTraceID = PerformanceTracer.shared.startTrace(.appLaunch)
    }

    private func endLaunchIfNeeded() {
        guard let id = launchTraceID else { return }
        PerformanceTracer.shared.endTrace(id)
        launchTraceID = nil
    }

    override init() {
        super.init()
        print(">>> main reached")
        LaunchLog.mark("AppDelegate.init")

        // Performance: start launch trace as early as possible.
        startLaunchIfNeeded()

        // Performance: mark milestones from system hooks.
        WebKitWarmupHooks.onFirstWebViewCreated = {
            Task { @MainActor in
                PerformanceTracer.shared.instantEvent(.firstWebViewReady)
            }
        }
        AppBootstrap.onAppInteractive = {
            Task { @MainActor [weak self] in
                self?.endLaunchIfNeeded()
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        LaunchLog.mark("AppDelegate.didFinishLaunching")
        return true
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Best-effort cleanup when the system discards scene sessions.
        // We avoid hardcoding any window/session mapping by reading userInfo.
        for session in sceneSessions {
            if let uuidString = session.userInfo?[SceneRestorationKeys.browserWindowUUID] as? String,
               let uuid = UUID(uuidString: uuidString) {
                Task { @MainActor in
                    appRoot?.appSessionController.removeWindow(id: uuid)
                }
            }
        }
    }

    // Remove scene configuration to let SwiftUI handle scenes
    // func application(
    //     _ application: UIApplication,
    //     configurationForConnecting connectingSceneSession: UISceneSession,
    //     options: UIScene.ConnectionOptions
    // ) -> UISceneConfiguration {
    //     let config = UISceneConfiguration(
    //         name: "Default Configuration",
    //         sessionRole: connectingSceneSession.role
    //     )
    //     config.delegateClass = SceneDelegate.self
    //     return config
    // }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        LaunchLog.mark("AppDelegate.handleEventsForBackgroundURLSession id=\(identifier)")

        // Ensure the shared facade (and its internal download center) exists.
        // Prefer the app-scope dependencies if already wired.
        if let appRoot {
            SafariLikeAppFacade.bootstrapSharedIfNeeded(
                websitePreferencesStore: appRoot.websitePreferencesStore,
                downloadFileIO: appRoot.downloadFileIO
            )
        } else {
            // Best-effort fallback for background relaunch before SwiftUI composition is ready.
            SafariLikeAppFacade.bootstrapSharedIfNeeded(
                websitePreferencesStore: SafariLikeStores.makeWebsitePreferencesStore(),
                downloadFileIO: DefaultDownloadFileIO()
            )
        }

        SafariLikeAppFacade.shared.handleBackgroundURLSession(
            identifier: identifier,
            completionHandler: completionHandler
        )
    }
}
