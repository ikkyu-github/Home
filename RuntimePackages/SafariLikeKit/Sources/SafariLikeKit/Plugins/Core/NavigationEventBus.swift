import Foundation
import SafariLikeCoreKit
/// A minimal, read-only navigation event surface for plugins.
///
/// This intentionally exposes only high-level events and does not allow
/// interception or direct WebView access.
public struct NavigationEventBus: Sendable {
    private let subscribeImpl: @Sendable (@escaping @MainActor (NavigationEvent) -> Void) async throws -> PluginEventSubscription
    init(
        subscribe: @escaping @Sendable (@escaping @MainActor (NavigationEvent) -> Void) async throws -> PluginEventSubscription
    ) {
        self.subscribeImpl = subscribe
    }
    /// Subscribe to navigation events.
    ///
    /// Retain the returned token to keep the subscription alive.
    public func subscribe(
        _ handler: @escaping @MainActor (NavigationEvent) -> Void
    ) async throws -> PluginEventSubscription {
        try await subscribeImpl(handler)
    }
}
