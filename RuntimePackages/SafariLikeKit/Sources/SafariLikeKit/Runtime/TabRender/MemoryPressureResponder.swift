import Foundation
import SafariLikeCoreKit
/// Centralizes memory pressure handling for a window's tab runtime.
///
/// Policy:
/// - Prefer discarding/suspending background tabs first.
/// - Preserve active, pinned/locked, and recently used tabs (delegated to DiscardController policy).
@MainActor
final class MemoryPressureResponder {
    private weak var tabManager: TabManager?
    private var token: UUID?
    init(tabManager: TabManager) {
        self.tabManager = tabManager
    }
    func start() {
        stop()
        token = EngineController.shared.addMemoryPressureObserver { [weak self] event in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let tabManager = self.tabManager else { return }
                tabManager.handleMemoryPressureEvent(event)
            }
        }
    }
    func stop() {
        if let token {
            EngineController.shared.removeMemoryPressureObserver(token)
            self.token = nil
        }
    }
}
