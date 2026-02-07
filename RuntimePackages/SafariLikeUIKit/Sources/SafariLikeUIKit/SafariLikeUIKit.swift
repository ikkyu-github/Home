
import SwiftUI

// MARK: - Public Module Exports

/// SafariLikeUIKit: UIKit/WebKit integration layer for the Safari-like browser.
///
/// **Framework Independence:**
/// SafariLikeUIKit is a reusable framework with NO hardcoded app-specific values.
/// It can be imported into any iOS app (webOS, MyBrowser, SomeOtherBrowser, etc.)
/// without modifications.
///
/// **No App Coupling:**
/// - ✅ No webOS app references
/// - ✅ No hardcoded bundle identifiers
/// - ✅ No app-specific file paths
/// - ✅ All configuration via dependency injection
/// - ✅ Works in single and multi-window environments
///
/// **Public API:**
/// - `SafariLikeUIKitFactory` - Composition root for creating UI layer implementations
/// - `SafariLikeUIKitHost` - UIKit ↔ SwiftUI bridge (main entry point)
/// - `SafariLikeBrowserView` - SwiftUI view (from SafariLikeKit)
/// - `SafariLikeConfiguration` - Configuration model (from SafariLikeKit)
/// - `BrowserSceneSession` - Session type (from SafariLikeKit)
/// - `WebsitePreferencesStore` - Per-website preferences with WKWebViewConfiguration integration
///
/// **How to Use in Your App:**
/// ```swift
/// // 1. Import
/// import SafariLikeUIKit
///
/// // 2. Create factory during app initialization
/// let factory = SafariLikeUIKitFactory(thumbnailStoreProvider: SafariLikeKit.TabThumbnailStore())

///
/// // 2. Get protocol-based implementations (recommended)
/// let thumbnails: TabThumbnailProviding = factory.makeThumbnailProvider()
/// let preferences: WebsitePreferencesProviding = factory.makePreferencesProvider()
///
/// // 3. Inject into view hierarchy via EnvironmentObject
/// browser.environmentObject(factory.makeThumbnailProvider())
/// ```
///
/// **Architecture:**
/// - Implements Core protocols in concrete UIKit/WebKit context
/// - Factory pattern centralizes instance creation
/// - Consumers depend on protocols, not concrete types
/// - Re-exports SwiftUI/configuration types from SafariLikeKit for convenience
///
/// **Thread Safety:**
/// - All public classes use @MainActor for UI safety
/// - Safe for SwiftUI/UIKit consumption directly
///
/// **Module Structure:**
/// ```
/// SafariLikeUIKit/
///   Composition/
///     SafariLikeUIKitFactory - Composition root (creates all implementations)
///   SafariLikeUIKitHost      - UIKit bridge
///   TabThumbnailStore        - Thumbnails submodule
///   WebsitePreferencesStore  - Preferences submodule
///   Re-exports               - Configuration, BrowserView, BrowserSceneSession
/// ```

// SafariLikeUIKit does not export a concrete TabThumbnailStore; inject via protocols.

// WebsitePreferencesStore is exported directly from WebsitePreferences submodule
// Import path: SafariLikeUIKit.WebsitePreferencesStore (public class in WebsitePreferences/WebsitePreferencesStore.swift)

// SafariLikeUIKitFactory is exported directly from Composition submodule
// Import path: SafariLikeUIKit.SafariLikeUIKitFactory (public class in Composition/SafariLikeUIKitFactory.swift)
