import Foundation

/// Core boundary for delivering memory-pressure signals to the engine.
///
/// - Core (SafariLikeCoreKit): depends on this protocol only.
/// - UI layer (SafariLikeUIKit/App): implements this using UIKit notifications.
@MainActor
public protocol EngineMemoryPressureSource: AnyObject {
    /// Called by the engine to register a single handler.
    /// Implementations should invoke the handler on the main actor.
    func setHandler(_ handler: (@Sendable (EngineController.MemoryPressureLevel) -> Void)?)
}
