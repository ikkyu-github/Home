import Foundation
import SafariLikeCoreKit
enum SplitFeatureFlags {
    static let enableAutoCompanionDefault = true
    static let enableSidebarDefault = true
    static let enableTabOverviewGestures = true
    /// Safari-like behavior: keep cookies/login across app relaunch.
    /// - true: use WKWebsiteDataStore.default()
    /// - false: use WKWebsiteDataStore.nonPersistent() per window/scene
    static let usePersistentWebsiteDataStore = true
}
