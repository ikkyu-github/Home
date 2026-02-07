import Foundation

/// A minimal runtime handle for UI/App code.
///
/// This exists to avoid exposing runtime internals (e.g. TabManager) across the UI boundary.
public protocol BrowserRuntimeIntentDispatching: AnyObject {
    @MainActor
    func send(intent: BrowserRuntimeIntent)
}
