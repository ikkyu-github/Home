import Foundation
import CoreGraphics
import WebKit
import SafariLikeCoreKit
/// Minimal UIKit-free thumbnail store for SwiftUI previews and tests.
///
/// - Stores thumbnail bytes in-memory.
/// - Capture methods are no-ops (previews typically don't have live WKWebView snapshots).
@MainActor
final class PreviewThumbnailStore: ThumbnailCapturing {
    private var store: [UUID: Data] = [:]
    func thumbnailData(for tabID: UUID) -> Data? {
        store[tabID]
    }
    func setThumbnailData(_ data: Data?, for tabID: UUID) {
        store[tabID] = data
    }
    func hasThumbnail(for tabID: UUID) -> Bool {
        store[tabID] != nil
    }
    func capture(
        tabID: UUID,
        webView: WKWebView,
        targetWidth: CGFloat?,
        minInterval: CFTimeInterval
    ) {
        // Intentionally no-op in preview context.
    }
    func captureForOverviewIfNeeded(tabID: UUID, webView: WKWebView) {
        // Intentionally no-op in preview context.
    }
}
