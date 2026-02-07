import Foundation
import SafariLikeCoreKit
public enum AppBootPhase: Sendable {
    case coldStart
    case restored
    case resumed
}
public actor AppBootstrap {
    /// Called when bootstrap finalizes and the app is considered interactive.
    public nonisolated(unsafe) static var onAppInteractive: (@MainActor () -> Void)?
    private var didStart = false
    private var firstFrameReady = false
    private var bootstrapTask: Task<Void, Never>?
    private var warmupTask: Task<Void, Never>?
    private var pendingInitialRestore: InitialRestoreRequest?
    private struct InitialRestoreRequest: Sendable {
        let session: BrowserSceneSession
        let openBlank: Bool
    }
    public init() {}
    public func markFirstFrameReady() async {
        guard firstFrameReady == false else { return }
        firstFrameReady = true
        await MainActor.run {
            LaunchTracer.shared.mark("ui.first.frame.ready")
        }
    }
    public func provideInitialSceneSessionForRestore(_ session: BrowserSceneSession, openBlank: Bool) async {
        pendingInitialRestore = InitialRestoreRequest(session: session, openBlank: openBlank)
    }
    public func start(phase: AppBootPhase) async {
        if let task = bootstrapTask {
            await task.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runStartup(phase: phase)
        }
        bootstrapTask = task
        await task.value
    }
    public func sceneActivated() async {
        if warmupTask == nil {
            warmupTask = Task { [weak self] in
                guard let self else { return }
                await self.warmupWebKitIfNeeded()
            }
        }
    }
    public func sceneBackgrounded() async {
        warmupTask?.cancel()
        warmupTask = nil
    }
    // MARK: - Startup stages
    private func runStartup(phase: AppBootPhase) async {
        guard didStart == false else { return }
        didStart = true
        await MainActor.run {
            LaunchTracer.shared.mark("app.start.begin", "phase=\(phase)")
        }
        await waitForFirstFrameReady()
        await MainActor.run {
            SafariLikeRuntime.configureEngineIfNeeded()
        }
        await loadSettings()
        await initMetrics()
        await initPluginRuntimeLightweight()
        await restoreSessionIfNeeded()
        await warmupWebKitIfNeeded()
        await finalize()
    }
    private func waitForFirstFrameReady() async {
        // Ensure UI renders first.
        while firstFrameReady == false {
            if Task.isCancelled { return }
            await Task.yield()
        }
    }
    private func loadSettings() async {
        if Task.isCancelled { return }
        // SafariLikeKit-level placeholder: app-specific settings live in the app target.
        await Task.yield()
        await MainActor.run {
            LaunchTracer.shared.mark("settings.loaded")
        }
    }
    private func initMetrics() async {
        if Task.isCancelled { return }
        await MainActor.run {
            // Metrics objects are singletons; touching them ensures initialization.
            _ = LaunchTracer.shared
            // Install policy providers early.
            PolicyBootstrap.installIfNeeded()
        }
    }
    private func initPluginRuntimeLightweight() async {
        if Task.isCancelled { return }
        await Task.yield()
        await MainActor.run {
            PluginBootstrap.registerBuiltInPlugins()
            LaunchTracer.shared.mark("plugins.lightweight.ready")
        }
    }
    private func restoreSessionIfNeeded() async {
        if Task.isCancelled { return }
        // Give the UI a bit more time before attempting restore.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 75_000_000)
        await MainActor.run {
            LaunchTracer.shared.mark("session.restore.begin")
        }
        // Wait briefly for the first scene session to be created and provided.
        let maxWaitNanos: UInt64 = 1_500_000_000
        var waited: UInt64 = 0
        let step: UInt64 = 50_000_000
        while pendingInitialRestore == nil && waited < maxWaitNanos {
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: step)
            waited += step
        }
        if let request = pendingInitialRestore {
            pendingInitialRestore = nil
            if Task.isCancelled { return }
            if request.openBlank {
                await request.session.sessionStore.replaceAllTabs([BrowserTab()], selectedTabID: nil)
            } else {
                await request.session.restoreInitialPersistedStateIfAvailable()
            }
        }
        await MainActor.run {
            LaunchTracer.shared.mark("session.restore.end")
        }
    }
    private func warmupWebKitIfNeeded() async {
        if Task.isCancelled { return }
        // Delay warmup until after restore has had a chance to run.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 150_000_000)
        await MainActor.run {
            LaunchTracer.shared.mark("webkit.warmup.begin")
        }
        await WebKitWarmup.shared.warmupIfNeeded()
        await MainActor.run {
            LaunchTracer.shared.mark("webkit.warmup.end")
        }
    }
    private func finalize() async {
        if Task.isCancelled { return }
        await MainActor.run {
            LaunchTracer.shared.mark("app.start.end")
            Self.onAppInteractive?()
        }
    }
}
