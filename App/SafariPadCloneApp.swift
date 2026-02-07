import SwiftUI
import SafariLikeKit
import SafariLikeKit

/// App entry point with multi-window support.
///
/// **Architecture:**
/// - Uses WindowGroup for multi-window support
/// - Each window gets its own BrowserWindowSession
/// - Each window gets its own SplitBrowserViewModel (NOT singleton)
/// - Supports opening new windows via external events
/// - Handles deep linking and URL schemes
///
/// **Multi-Window Design:**
/// - WindowGroup creates independent browser windows
/// - Each window: independent tabs, history, navigation state
/// - Shared services: bookmarks, downloads, website preferences
/// - Active window tracking via SceneSessionRegistry
@main
struct SafariPadCloneApp: App {
    // App-level responsibility: declare scene(s) for multi-window support

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var appRoot: AppCompositionRoot

    init() {
        let root = AppCompositionRoot()
        _appRoot = StateObject(wrappedValue: root)
        appDelegate.appRoot = root
    }

    var body: some Scene {
        WindowGroup {
            SceneRootView(appRoot: appRoot)
                .environmentObject(appRoot.lifecycleCoordinator)
                .environmentObject(appRoot.crashGuard)
                .environmentObject(appRoot.sceneMetrics)
                .environmentObject(appRoot.settings)
                // Scene-level source of truth for size/safe area/orientation.
                .overlay(
                    SceneMetricsReader(metrics: appRoot.sceneMetrics)
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                        .allowsHitTesting(false)
                )
                .task {
                    await appRoot.bootstrapIfNeeded()
                }
                .onChange(of: scenePhase) { newPhase in
                    Task {
                        await appRoot.lifecycleCoordinator.onScenePhaseChanged(newPhase)
                    }
                }
        }
        .commands {
            SafariLikeBrowserCommands()
        }
    }
}

/// One SceneCompositionRoot per SwiftUI scene/window.
///
/// This view is allowed to create composition roots, but it must not
/// construct core/runtime objects directly; those belong inside the roots.
private struct SceneRootView: View {
    let appRoot: AppCompositionRoot

    @StateObject private var sceneRoot: SceneCompositionRoot

    init(appRoot: AppCompositionRoot) {
        self.appRoot = appRoot
        _sceneRoot = StateObject(wrappedValue: SceneCompositionRoot(appRoot: appRoot))
    }

    var body: some View {
        AppRootView(sceneRoot: sceneRoot)
            .environmentObject(sceneRoot.windowLifecycleCoordinator)
    }
}
