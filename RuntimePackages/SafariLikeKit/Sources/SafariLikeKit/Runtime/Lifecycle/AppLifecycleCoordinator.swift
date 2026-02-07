import Foundation
import SwiftUI
import Combine
import SafariLikeCoreKit
@MainActor
public final class AppLifecycleCoordinator: ObservableObject {
    public enum State: Sendable {
        case launching
        case active
        case background
        case terminating
    }
    @Published public private(set) var state: State = .launching
    internal let siteHeuristicsStore: SiteHeuristicsStore
    internal let runtimeRegistry: SceneRuntimeRegistry
    private let bootstrap: AppBootstrap
    /// True when more than one scene/window is currently registered.
    public var isMultiWindowActive: Bool { runtimeRegistry.contexts.count > 1 }
    private var didStartBootstrap = false
#if DEBUG
    /// Debug-only read-only signal for diagnostics overlays.
    public func debugLastReconcileAt(sceneID: String, tabID: UUID) -> Date? {
        runtimeRegistry.contexts[SceneID(raw: sceneID)]?.debugLastReconcileAt(tabID: tabID)
    }
#endif
    public init() {
        // Process-wide domain store. Must be reused across all scenes.
        let store = SiteHeuristicsStore()
        self.siteHeuristicsStore = store
        self.runtimeRegistry = SceneRuntimeRegistry(siteHeuristicsStore: store)
        self.bootstrap = AppBootstrap()
    }

    public func markFirstFrameReady() async {
        await bootstrap.markFirstFrameReady()
    }
    private func existingContext(for sceneID: SceneID) -> SceneRuntimeContext? {
        runtimeRegistry.contexts[sceneID]
    }
    /// Scene-scoped runtime context suitable for injection into SwiftUI.
    ///
    /// Returns nil until the scene has been registered via `LifecycleCoordinator.registerScene`.
    public func sceneRuntimeContext(for sceneID: SceneID) -> SceneRuntimeContext? {
        existingContext(for: sceneID)
    }
    /// Escape hatch used by runtime operations (e.g. forced attach).
    internal func updateAttachmentState(sceneID: String, tabID: UUID, state: WebViewAttachmentState) {
        // Single-writer rule: request; the per-scene AttachmentCoordinator applies.
        existingContext(for: SceneID(raw: sceneID))?.attachmentCoordinator.requestRuntimeStateOverride(tabID: tabID, desired: state)
    }
    /// Read-only: per-scene attachment status.
    public func attachmentStatus(sceneID: String) -> WebViewAttachmentStatus? {
        runtimeRegistry.contexts[SceneID(raw: sceneID)]?.currentAttachmentStatus()
    }
    /// Read-only: subscribe to attachment status updates for a given scene.
    ///
    /// This is the preferred way for UI/chrome to react to attachment state without
    /// maintaining redundant ready/attach flags.
    func attachmentStatusPublisher(sceneID: String) -> AnyPublisher<WebViewAttachmentStatus?, Never> {
        runtimeRegistry.contexts[SceneID(raw: sceneID)]?.attachmentStatusPublisher()
            ?? Just<WebViewAttachmentStatus?>(nil).eraseToAnyPublisher()
    }
    // MARK: - Scene Registration (called by LifecycleCoordinator)
    internal func registerScene(sceneID: String, tabManager: TabManager, core: SafariLikeCoreKit.SceneRuntimeContext) {
        _ = runtimeRegistry.ensureContext(sceneID: SceneID(raw: sceneID), tabManager: tabManager, core: core)
    }
    internal func unregisterScene(sceneID: String) {
        runtimeRegistry.remove(sceneID: SceneID(raw: sceneID))
    }
    public func onScenePhaseChanged(_ phase: ScenePhase) async {
        switch phase {
        case .active:
            await onAppBecameActive()
        case .background:
            await onAppEnteredBackground()
        case .inactive:
            // Treat inactive as background-ish for lifecycle purposes.
            await onAppEnteredBackground()
        @unknown default:
            break
        }
    }
    public func onAppBecameActive() async {
        // Defer publishing out of the view update cycle.
        Task { @MainActor [weak self] in
            self?.state = .active
        }
        if didStartBootstrap == false {
            didStartBootstrap = true
            await bootstrap.start(phase: .coldStart)
        }
        await bootstrap.sceneActivated()
        // Restore WebKit runtime on foreground (does not create a visible WKWebView).
        // Flow an explicit per-scene context through the engine layer.
        for context in runtimeRegistry.contexts.values {
            EngineController.shared.restoreAfterForeground(context: context.core)
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            for context in self.runtimeRegistry.contexts.values {
                context.setAppIsActive(true)
            }
        }

        #if DEBUG
        await debugPrintSafariParityReportIfRequested()
        #endif
    }
    public func onAppEnteredBackground() async {
        // Defer publishing out of the view update cycle.
        Task { @MainActor [weak self] in
            self?.state = .background
            guard let self else { return }
            for context in self.runtimeRegistry.contexts.values {
                context.setAppIsActive(false)
            }
        }
        await bootstrap.sceneBackgrounded()
        for context in runtimeRegistry.contexts.values {
            EngineController.shared.prepareForBackground(context: context.core)
        }
    }
    // MARK: - Browser Runtime Orchestration
    internal func handleBrowserRuntimeEvent(
        sceneID: String,
        event: LifecycleCoordinator.BrowserRuntimeEvent,
        viewModel: SplitBrowserViewModel,
        tabManager: TabManager
    ) {
        // Keep the coordinator itself as a router. Business logic lives in the per-scene context.
        existingContext(for: SceneID(raw: sceneID))?.handleBrowserRuntimeEvent(event, viewModel: viewModel, tabManager: tabManager)
    }
    internal func requestReconcile(sceneID: String, tabID: UUID, viewModel: SplitBrowserViewModel, tabManager: TabManager, reason: String) {
        existingContext(for: SceneID(raw: sceneID))?.requestReconcile(tabID: tabID, viewModel: viewModel, tabManager: tabManager, reason: reason)
    }
}
