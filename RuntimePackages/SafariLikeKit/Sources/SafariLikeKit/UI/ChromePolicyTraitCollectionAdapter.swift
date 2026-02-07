import UIKit
import SafariLikeCoreKit
/// UIKit adapter for the core `ChromePolicy`.
///
/// Kept out of SafariLikeKit/Core to preserve UIKit-free core layering.
public extension ChromePolicy {
    @MainActor
    static func defaultPolicy(for traitCollection: UITraitCollection) -> ChromePolicy {
        defaultPolicy(traits: traitCollection)
    }
}
extension UITraitCollection: ChromePolicyTraits {
    public var isCompactHorizontalSizeClass: Bool {
        horizontalSizeClass == .compact
    }
}
