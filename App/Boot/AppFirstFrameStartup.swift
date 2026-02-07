import SafariLikeKit

@MainActor
struct AppFirstFrameStartup {
    let crashGuard: CrashGuard
    let lifecycleCoordinator: AppLifecycleCoordinator

    func run() async {
        LaunchLog.mark("AppFirstFrameStartup.run.begin")
        // Ensure UI frame first.
        await Task.yield()
        await lifecycleCoordinator.markFirstFrameReady()
        LaunchLog.mark("AppFirstFrameStartup.firstFrameReady")
        AppPerformance.markFirstUIRendered()
        crashGuard.evaluateOnAppStart()

        // Keep first-frame path short: schedule bootstrap work without blocking.
        Task { @MainActor in
            await lifecycleCoordinator.onAppBecameActive()
            LaunchLog.mark("AppFirstFrameStartup.onAppBecameActive.done")
        }

        LaunchLog.mark("AppFirstFrameStartup.run.end")
    }
}
