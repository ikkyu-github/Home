import Foundation
import SwiftUI
import UIKit
import WebKit
import SafariLikeContracts
import Combine
import SafariLikeCoreKit
/// ObservableObject adapter for thumbnail management used by the SwiftUI layer.
///
/// Responsibilities:
/// - Wraps a core ThumbnailCapturing implementation (e.g. TabThumbnailStore)
/// - Projects thumbnail changes via a lightweight @Published revision signal
/// - Provides UIImage-based read API for SwiftUI views (e.g. SafariTabCard)
/// - Forwards capture operations back to the underlying store
@MainActor
final class ThumbnailChromeAdapter: ObservableObject, ThumbnailCapturing {
    // MARK: - Backing store
    private let store: any ThumbnailCapturing
    // MARK: - Change signal for SwiftUI
    /// Lightweight revision counter so views can refresh when thumbnails change
    @Published private(set) var revision: UInt64 = 0
    init(store: any ThumbnailCapturing) {
        self.store = store
    }
    // MARK: - TabThumbnailProviding
    func thumbnailData(for tabID: UUID) -> Data? {
        store.thumbnailData(for: tabID)
    }
    func setThumbnailData(_ data: Data?, for tabID: UUID) {
        store.setThumbnailData(data, for: tabID)
        bumpRevision()
    }
    // MARK: - ThumbnailCapturing
    func hasThumbnail(for tabID: UUID) -> Bool {
        store.hasThumbnail(for: tabID)
    }
    func capture(
        tabID: UUID,
        webView: WKWebView,
        targetWidth: CGFloat?,
        minInterval: CFTimeInterval
    ) {
        store.capture(
            tabID: tabID,
            webView: webView,
            targetWidth: targetWidth,
            minInterval: minInterval
        )
        bumpRevision()
    }
    func captureForOverviewIfNeeded(tabID: UUID, webView: WKWebView) {
        store.captureForOverviewIfNeeded(tabID: tabID, webView: webView)
        bumpRevision()
    }
    // MARK: - UI helpers
    /// Convenience for SwiftUI views that need a UIImage thumbnail.
    func thumbnail(for tabID: UUID) -> UIImage? {
        guard let data = thumbnailData(for: tabID) else {
            return nil
        }
        return UIImage(data: data)
    }
    // MARK: - Internal helpers
    private func bumpRevision() {
        revision &+= 1
    }
}
