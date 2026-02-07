import Foundation

/// Saving and persistence helpers for BrowserSessionStore.
///
/// All session persistence logic is owned by BrowserCore.
/// SafariLikeKit and App must use these public APIs to trigger saves.
extension BrowserSessionStore {

    /// Persist the current session state to disk (or memory) immediately.
    ///
    /// This is a synchronous-safe wrapper around the internal persistence mechanism.
    /// Use this method when you need to ensure session changes are written before
    /// the app suspends or terminates.
    ///
    /// - Important: This method is the canonical save entry point for all session persistence.
    ///   Call this from App lifecycle methods (e.g., sceneWillResignActive, sceneDidEnterBackground).
    @MainActor
    public func persistNow() {
        saveNow()
    }
}
