import SafariLikeCoreKit
/// Core (UIKit-free) traits used to derive a `ChromePolicy`.
///
/// This keeps SafariLikeKit decoupled from UIKit while still allowing UI layers
/// to adapt platform trait collections into the core policy model.
public protocol ChromePolicyTraits {
    var isCompactHorizontalSizeClass: Bool { get }
}
public extension ChromePolicy {
    static func defaultPolicy<T: ChromePolicyTraits>(traits: T) -> ChromePolicy {
        defaultPolicy(isCompact: traits.isCompactHorizontalSizeClass)
    }
}
