import Foundation
import WebKit
import ObjectiveC

/// Lightweight runtime marker used to validate that `WKWebView` instances were
/// created through the single allocator: `WebViewPool.makeWebView(configuration:)`.
///
/// This is intentionally implemented with associated objects so it:
/// - requires no subclassing,
/// - does not change WebKit behavior,
/// - adds no new global mutable state (marker is per-instance).
extension WKWebView {
    private static var safariLikeAllocationTagKey: UInt8 = 0
    private static var safariLikeOwningPoolIDKey: UInt8 = 0
    private static var safariLikeOwningPoolOwnerIdentityKey: UInt8 = 0

    /// True iff this instance was created by `WebViewPool.makeWebView(configuration:)`.
    public var safariLikeWasAllocatedByWebViewPool: Bool {
        (objc_getAssociatedObject(self, &Self.safariLikeAllocationTagKey) as? Bool) ?? false
    }

    /// Unique identity token for the `WebViewPool` instance that owns this `WKWebView`.
    ///
    /// This is used to prevent a `WKWebView` from being re-parented across scene/window pools.
    public var safariLikeOwningWebViewPoolID: UUID? {
        objc_getAssociatedObject(self, &Self.safariLikeOwningPoolIDKey) as? UUID
    }

    /// Human-readable owner identity (typically derived from the pool's label).
    /// Diagnostics only; do not treat as a stable identifier.
    public var safariLikeOwningWebViewPoolOwnerIdentity: String? {
        objc_getAssociatedObject(self, &Self.safariLikeOwningPoolOwnerIdentityKey) as? String
    }

    @MainActor
    internal func safariLikeMarkAllocatedByWebViewPool() {
        objc_setAssociatedObject(self, &Self.safariLikeAllocationTagKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @MainActor
    internal func safariLikeMarkOwnedByWebViewPool(poolID: UUID, ownerIdentity: String) {
        objc_setAssociatedObject(self, &Self.safariLikeOwningPoolIDKey, poolID, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &Self.safariLikeOwningPoolOwnerIdentityKey, ownerIdentity, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
