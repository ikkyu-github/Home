import Combine
import Foundation
import SafariLikeCoreKit
/// Tracks the currently active `BrowserSceneSession` for app-level helpers.
///
/// This is used by `AppWindowActions` on platforms that do not support
/// multi-window (e.g. iPhone) to map "window" actions to tab-level
/// operations within the active session.
@MainActor
final class AppBrowserSessionRegistry: @preconcurrency ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private(set) weak var activeSession: BrowserSceneSession?
    init() {}
    func registerActiveSession(_ session: BrowserSceneSession) {
        objectWillChange.send()
        activeSession = session
    }
    func unregisterSession(_ session: BrowserSceneSession) {
        // Only clear if we're unregistering the current active session
        if activeSession === session {
            objectWillChange.send()
            activeSession = nil
        }
    }
}
