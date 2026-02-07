import Foundation
import SafariLikeCoreKit
public struct WindowReducer {
    public static func reduce(state: WindowState, event: WindowEvent) -> WindowState {
        let newState = state
        switch event {
        case .openWindow:
            // No-op for now, handled by creation
            break
        case .closeWindow:
            // Mark as closed, or remove from registry elsewhere
            break
        case .activateWindow:
            // Could update lastActiveAt, etc.
            break
        case .persistSessionNow:
            // No-op, effect handled elsewhere
            break
        case .restoreSession:
            // No-op, effect handled elsewhere
            break
        }
        return newState
    }
}
