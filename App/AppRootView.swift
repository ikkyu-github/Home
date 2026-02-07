import SwiftUI
import SafariLikeKit
import SafariLikeKit
import UIKit

@MainActor
private final class AppBrowserSessionProvider {
    init() {}
}

struct AppRootView: View {

    @ObservedObject var sceneRoot: SceneCompositionRoot

    init(sceneRoot: SceneCompositionRoot) {
        self.sceneRoot = sceneRoot
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Scene

    @SceneStorage("sceneID") private var storedSceneID: String?
    @SceneStorage(SceneRestorationKeys.browserWindowUUID) private var storedBrowserWindowUUID: String?
    @EnvironmentObject private var crashGuard: CrashGuard
    @EnvironmentObject private var lifecycle: AppLifecycleCoordinator
    @EnvironmentObject private var windowLifecycleCoordinator: LifecycleCoordinator
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var sceneMetrics: SceneMetrics

    @State private var uiSceneSession: UISceneSession?

    // MARK: - URL Routing (per scene)

    private enum PendingURLOpenMode {
        case currentWindow
        case newWindow
    }

    @State private var pendingOpenURL: URL?
    @State private var pendingOpenURLMode: PendingURLOpenMode = .currentWindow

    // MARK: - App State

    /// UI-level browser configuration
    @State private var configuration: SafariLikeConfiguration = .default

    private static var isUITestHarnessEnabled: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["UI_TEST_HARNESS"] == "1" { return true }
        // Common XCUITest launch argument conventions.
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--uiTestHarness") || args.contains("-uiTestHarness")
    }

    // MARK: - Body

    var body: some View {
        let session = sceneRoot.session
        let windowID = sceneRoot.windowID
        let resolvedSceneID = sceneRoot.sceneID
        let sceneRuntimeContext = sceneRoot.runtimeContext

        ZStack {
            if let session, let windowID, !resolvedSceneID.isEmpty {
                GeometryReader { geometry in
                    let debugEnabled = UserDefaults.standard.bool(forKey: "ui.debugOverlayEnabled")
                    let isUITestHarnessEnabled = Self.isUITestHarnessEnabled
                    let layoutMode = BrowserLayoutPolicy.resolve(
                        hSizeClass: horizontalSizeClass,
                        safeWidth: geometry.size.width
                    )

                    Group {
                        if let sceneRuntimeContext {
                            SafariLikeBrowserView(
                                session: session,
                                context: sceneRuntimeContext,
                                initialURL: nil,
                                configuration: $configuration,
                                makeSettingsView: { [settings] in
                                    AnyView(
                                        PerformanceSettingsSheet(settings: settings)
                                    )
                                }
                            )
                        } else {
                            ProgressView(bootstrapStatusText)
                        }
                    }
                    .environment(\.browserLayoutMode, layoutMode)
                    .environmentObject(sceneRoot.relatedChrome)
                    .environment(\.browserWindowID, windowID)
                    .environment(\.browserRuntime, session)
                    .safariLikeWebPermissionPrompts()
                    .overlay(alignment: .topTrailing) {
                        #if DEBUG
                        if debugEnabled {
                            LayoutModeDebugOverlay(
                                debugName: layoutMode.debugName,
                                width: geometry.size.width,
                                height: geometry.size.height,
                                horizontalSizeClass: horizontalSizeClass
                            )
                        }
                        #endif
                    }
                    .overlay(alignment: .topLeading) {
                        #if DEBUG
                        if isUITestHarnessEnabled {
                            SceneMetricsTestHookView(sceneMetrics: sceneMetrics)
                        }
                        #endif
                    }
                    .preferredColorScheme(
                        settings.darkModeEnabled ? .dark : .light
                    )
                    .onReceive(NotificationCenter.default.publisher(for: .appDarkModeChanged)) { note in
                        guard let isDark = note.object as? Bool else { return }
                        settings.darkModeEnabled = isDark
                    }
                    .onChange(of: settings.contentBlockerEnabled) { newValue in
                        configuration.contentBlockerEnabled = newValue
                    }
                    .onChange(of: settings.searchEngine) { newValue in
                        configuration.searchEngineURL = newValue.searchURL.absoluteString
                    }
                    .onAppear {
                        sceneRoot.registerLifecycleIfNeeded(
                            scenePhase: scenePhase,
                            lifecycle: lifecycle
                        )
                        applyPendingOpenURLIfPossible()
                    }
                    .onDisappear {
                        windowLifecycleCoordinator.handleWindowEvent(sceneID: resolvedSceneID, event: .disconnect)
                    }
                }
            } else {
                // UI-first: show something on-screen, then bootstrap core in a task.
                ProgressView(bootstrapStatusText)
            }
        }
        .onOpenURL { url in
            // Route external URLs into *this* window's active tab.
            pendingOpenURL = url
            pendingOpenURLMode = .currentWindow
            applyPendingOpenURLIfPossible()
        }
        .onContinueUserActivity(OpenURLUserActivity.activityType) { activity in
            // New-window routing: the scene was created with a userActivity payload.
            guard let url = OpenURLUserActivity.extractURL(from: activity) else { return }
            pendingOpenURL = url
            pendingOpenURLMode = .newWindow
            applyPendingOpenURLIfPossible()
        }
        .background(
            SceneSessionReader { session in
                uiSceneSession = session
            }
            .frame(width: 0, height: 0)
        )
        .onChange(of: scenePhase) { newPhase in
            // Ensure the coordinator receives real foreground/background signals.
            // Without this, a cold launch can miss the activation window and leave the
            // WebView attachment stuck in `.attaching` indefinitely.
            sceneRoot.onScenePhaseChanged(newPhase)
        }
        .task(id: sceneBootstrapKey) {
            await bootstrapSceneIfNeeded()
        }
        .onAppear {
            // Keep configuration in sync with settings without touching WebKit.
            configuration.contentBlockerEnabled = settings.contentBlockerEnabled
            configuration.searchEngineURL = settings.searchEngine.searchURL.absoluteString
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            // Best-effort last-chance persistence.
            if !sceneRoot.sceneID.isEmpty {
                storedSceneID = sceneRoot.sceneID
            }
            windowLifecycleCoordinator.handleAppEvent(.terminate)
            crashGuard.markCleanExitAfterBestEffortFlush()
        }
    }

    // MARK: - Private

    private var sceneBootstrapKey: String {
        uiSceneSession?.persistentIdentifier
            ?? storedBrowserWindowUUID
            ?? storedSceneID
            ?? "boot"
    }

    private var bootstrapStatusText: String {
        switch sceneRoot.bootstrapState {
        case .idle:
            return "Preparing…"
        case .bootstrapping:
            return "Starting…"
        case .ready:
            return "Ready"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }

    private func bootstrapSceneIfNeeded() async {
        // UI-first: yield and let SwiftUI render before doing heavy work.
        LaunchLog.mark("AppRootView.bootstrapSceneIfNeeded.begin")
        await Task.yield()

        // Note: `uiSceneSession` may arrive later; identity is still configured deterministically,
        // and `configureIdentityIfNeeded` will merge restoration metadata when it becomes available.

        let windowID: BrowserWindowID = {
            if let storedBrowserWindowUUID, let uuid = UUID(uuidString: storedBrowserWindowUUID) {
                return BrowserWindowID(uuid)
            }
            if let storedSceneID, let id = browserWindowID(from: storedSceneID) {
                storedBrowserWindowUUID = id.value.uuidString
                return id
            }
            let created = BrowserWindowID()
            storedBrowserWindowUUID = created.value.uuidString
            return created
        }()

        let sceneID: String = {
            if let uiSceneSession {
                return uiSceneSession.persistentIdentifier
            }
            return storedSceneID ?? windowID.value.uuidString
        }()

        storedSceneID = sceneID

        sceneRoot.configureIdentityIfNeeded(
            sceneID: sceneID,
            windowID: windowID,
            uiSceneSession: uiSceneSession
        )

        let openBlank = crashGuard.selectedLaunchAction == .some(.openBlank)
        await sceneRoot.bootstrapIfNeeded(
            configuration: configuration,
            openBlank: openBlank
        )

        LaunchLog.mark("AppRootView.bootstrapSceneIfNeeded.sceneReady")

        applyPendingOpenURLIfPossible()
    }

    private func applyPendingOpenURLIfPossible() {
        guard let session = sceneRoot.session else { return }
        // We consider the lifecycle "ready" once a runtime context exists.
        guard sceneRoot.runtimeContext != nil else { return }
        guard let url = pendingOpenURL else { return }

        switch pendingOpenURLMode {
        case .currentWindow:
            session.openURLInActiveTab(url)

        case .newWindow:
            session.openURLInNewTab(url, closeInitialBlankTabIfNeeded: true)
        }

        pendingOpenURL = nil
    }

    private func browserWindowID(from sceneID: String) -> BrowserWindowID? {
        // Preferred format: "scene_<UUID>". Fallback: raw UUID string.
        if let range = sceneID.range(of: "scene_") {
            let uuidString = String(sceneID[range.upperBound...])
            if let uuid = UUID(uuidString: uuidString) {
                return BrowserWindowID(uuid)
            }
        } else if let uuid = UUID(uuidString: sceneID) {
            return BrowserWindowID(uuid)
        }
        return nil
    }

}
