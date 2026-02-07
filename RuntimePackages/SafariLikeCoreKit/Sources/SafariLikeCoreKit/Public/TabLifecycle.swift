import Foundation

/// Lifecycle control for a tab engine.
///
/// Threading: All requirements are expected to be called
/// from the main actor when used with the default CoreKit
/// implementation (TabWebStore).
public protocol TabLifecycle: AnyObject {
    /// Prepare the tab to start observing and loading.
    ///
    /// Threading: Call on the main actor.
    @MainActor
    func activate() async

    /// Tear down resources and mark the tab as no longer usable.
    ///
    /// Threading: Call on the main actor.
    @MainActor
    func invalidate() async
}

/// Default CoreKit implementation.
extension TabWebStore: TabLifecycle {}
