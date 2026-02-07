import Foundation
import SafariLikeCoreKit
/// Safari-like render lifecycle for a single tab.
///
/// Important: This is about *rendering resources* (WKWebView vs snapshot), not whether a tab exists.
@MainActor
enum TabRenderState: Equatable, Sendable {
    /// Live and interactive WKWebView attached for the tab.
    case active
    /// Live WKWebView exists but is not the primary focused surface (e.g. split preview).
    case background
    /// No live WKWebView is attached; UI should render from a cached snapshot.
    case snapshotOnly
    /// WKWebView has been detached/released to reduce memory; snapshot may or may not exist.
    case suspended
    /// WKWebView/store has been evicted; tab must be restored/reloaded on activation.
    case discarded
}
