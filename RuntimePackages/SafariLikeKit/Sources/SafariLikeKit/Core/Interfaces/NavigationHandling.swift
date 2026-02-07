import Foundation
import SafariLikeCoreKit
/// Abstraction for omnibox / address bar navigation so UI/runtime
/// components do not depend directly on NavigationService.
@MainActor
protocol NavigationHandling: AnyObject {
    /// Load a URL string into the active tab, applying the same
    /// normalization and search handling used by NavigationService.
    func loadURLString(_ urlString: String, force: Bool)
}
