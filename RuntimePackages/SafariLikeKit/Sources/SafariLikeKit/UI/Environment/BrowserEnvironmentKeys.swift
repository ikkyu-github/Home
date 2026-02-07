import SwiftUI
import SafariLikeCoreKit
private struct BrowserWindowIDKey: EnvironmentKey {
    static let defaultValue: BrowserWindowID? = nil
}
private struct BrowserRuntimeKey: EnvironmentKey {
    static let defaultValue: (any BrowserRuntimeIntentDispatching)? = nil
}
public extension EnvironmentValues {
    /// Optional browser window identifier for app-level UI (e.g. plugin settings).
    var browserWindowID: BrowserWindowID? {
        get { self[BrowserWindowIDKey.self] }
        set { self[BrowserWindowIDKey.self] = newValue }
    }
    /// Optional runtime handle for app-level UI.
    var browserRuntime: (any BrowserRuntimeIntentDispatching)? {
        get { self[BrowserRuntimeKey.self] }
        set { self[BrowserRuntimeKey.self] = newValue }
    }
}
