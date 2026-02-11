import Foundation

/// Factory/provider for a tab thumbnail service.
///
/// This keeps downstream UI layers from depending on concrete runtime implementations.
/// Composition roots should inject a provider backed by the runtime's thumbnail store.
@MainActor
public protocol ThumbnailStoreProviding: AnyObject {
    func makeThumbnailProvider() -> any TabThumbnailProviding
}
