import Foundation
import SafariLikeCoreKit
/// High-level chrome style variants used by the UI layer.
///
/// This intentionally does **not** encode width breakpoints; it is driven by orientation.
public enum BrowserChromeStyle: Equatable, Sendable {
    /// Safari-like iPhone portrait chrome (bottom bar, minimal primary actions).
    case phonePortraitSafari
    /// Safari-like iPad / landscape chrome (top bar, tabs + sidebar affordances).
    case padLandscapeSafari
}
