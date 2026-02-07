import Foundation

/// High-level interface for driving a single browser tab.
///
/// Threading: All requirements are expected to be called
/// from the main actor when used with the default CoreKit
/// implementation (TabWebStore).
@MainActor
public protocol TabEngine: AnyObject {
    associatedtype State: TabStateRepresentable = TabWebStoreState

    /// Current tab state snapshot.
    var state: State { get }

    /// Observe state changes; handler is called on the main actor.
    ///
    /// Threading: Call on the main actor.
    @MainActor
    func observeState(_ handler: @escaping @MainActor (State) -> Void) -> UUID

    /// Remove a previously-registered state observer.
    ///
    /// Threading: Call on the main actor.
    @MainActor
    func removeStateObserver(_ id: UUID)

    /// Load a URL string into the tab.
    ///
    /// Threading: Call on the main actor.
    @MainActor
    func load(_ urlString: String, force: Bool)

    /// Load a search query using the configured search engine.
    ///
    /// Threading: Call on the main actor.
    @MainActor
    func loadSearch(query: String)

    /// Hint that the next load should bypass any smart split behavior.
    ///
    /// Threading: Call on the main actor.
    @MainActor
    func setBypassSmartSplitOnce()
}

/// Default CoreKit implementation backed by WebKit.
extension TabWebStore: TabEngine {}
