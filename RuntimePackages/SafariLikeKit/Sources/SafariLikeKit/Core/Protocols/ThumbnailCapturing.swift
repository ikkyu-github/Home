import Foundation
import CoreGraphics
import SafariLikeContracts
import WebKit
import SafariLikeCoreKit
// MARK: - ThumbnailCapturing (UI-facing Protocol)
/// Extended thumbnail provider interface used by UI/runtime layers.
///
/// This refines the core TabThumbnailProviding boundary with capture
/// operations that depend on WKWebView. Core layers should depend only
/// on TabThumbnailProviding, while SafariLikeKit UI/runtime code can
/// use ThumbnailCapturing for full functionality.
public protocol ThumbnailCapturing: TabThumbnailProviding {
    func hasThumbnail(for tabID: UUID) -> Bool
    func capture(
        tabID: UUID,
        webView: WKWebView,
        targetWidth: CGFloat?,
        minInterval: CFTimeInterval
    )
    func captureForOverviewIfNeeded(tabID: UUID, webView: WKWebView)
}
