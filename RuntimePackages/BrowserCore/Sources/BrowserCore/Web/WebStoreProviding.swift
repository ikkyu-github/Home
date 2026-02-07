import Foundation

/// Minimal protocol for a tab-scoped web runtime object that both:
/// - exposes current navigation state, and
/// - can be driven via navigation commands.
///
/// Concrete implementations live in higher layers (e.g. SafariLikeCoreKit's TabWebStore).
@MainActor
public protocol WebStoreProviding: WebNavigator {
    var tabID: UUID { get }
    var state: TabWebStoreState { get }
}
