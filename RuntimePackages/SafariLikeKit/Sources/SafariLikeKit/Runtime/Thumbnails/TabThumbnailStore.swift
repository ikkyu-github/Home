import Combine
import Foundation
import UIKit
import WebKit
import SafariLikeCoreKit
/// UIKit implementation of thumbnail storage + snapshot capture.
///
/// Clean architecture:
/// - Core depends on `BrowserCore.TabThumbnailProviding` (Data only)
/// - UI/runtime code can use `ThumbnailCapturing` for full functionality
@MainActor
public final class TabThumbnailStore: ObservableObject, ThumbnailCapturing {
    @Published public private(set) var revision: UInt64 = 0
    // MARK: - Storage (Source of truth = immutable bytes)
    private var encodedStore: [UUID: Data] = [:]
    private var inFlight: Set<UUID> = []
    private var lastCapturedAt: [UUID: CFTimeInterval] = [:]
    // MARK: - Limits
    private let maxEncoded: Int
    private let decodedCountLimit: Int
    private let decodedCostLimit: Int
    private let decodedCache = NSCache<NSUUID, UIImage>()
    // MARK: - Tuning
    private let jpegQuality: CGFloat = 0.72
    public init() {
#if targetEnvironment(macCatalyst)
        self.maxEncoded = 80
        self.decodedCountLimit = 50
        self.decodedCostLimit = 160 * 1024 * 1024
#else
        self.maxEncoded = 30
        self.decodedCountLimit = 20
        self.decodedCostLimit = 60 * 1024 * 1024
#endif
        decodedCache.countLimit = decodedCountLimit
        decodedCache.totalCostLimit = decodedCostLimit
    }
    // MARK: - TabThumbnailProviding
    public func thumbnailData(for tabID: UUID) -> Data? {
        encodedStore[tabID]
    }
    public func setThumbnailData(_ data: Data?, for tabID: UUID) {
        encodedStore[tabID] = data
        decodedCache.removeObject(forKey: tabID as NSUUID)
        touch(tabID)
        trimIfNeeded()
        bumpRevision()
    }
    // MARK: - ThumbnailCapturing
    public func hasThumbnail(for tabID: UUID) -> Bool {
        encodedStore[tabID] != nil
    }
    public func capture(
        tabID: UUID,
        webView: WKWebView,
        targetWidth: CGFloat? = nil,
        minInterval: CFTimeInterval = 0
    ) {
        let now = CACurrentMediaTime()
        if minInterval > 0, let last = lastCapturedAt[tabID], (now - last) < minInterval {
            return
        }
        guard !inFlight.contains(tabID) else { return }
        inFlight.insert(tabID)
        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = false
        if let targetWidth, targetWidth > 0 {
            config.snapshotWidth = targetWidth as NSNumber
        }
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            Task { @MainActor in
                guard let self else { return }
                self.inFlight.remove(tabID)
                guard let image else { return }
                guard let data = image.jpegData(compressionQuality: self.jpegQuality) else { return }
                self.encodedStore[tabID] = data
                self.lastCapturedAt[tabID] = CACurrentMediaTime()
                if let decoded = UIImage(data: data) {
                    self.decodedCache.setObject(
                        decoded,
                        forKey: tabID as NSUUID,
                        cost: self.estimatedImageCostBytes(decoded)
                    )
                } else {
                    self.decodedCache.removeObject(forKey: tabID as NSUUID)
                }
                self.touch(tabID)
                self.trimIfNeeded()
                self.bumpRevision()
            }
        }
    }
    public func captureForOverviewIfNeeded(tabID: UUID, webView: WKWebView) {
        let preferredWidth: CGFloat = 520
        if hasThumbnail(for: tabID) {
            capture(tabID: tabID, webView: webView, targetWidth: preferredWidth, minInterval: 6.0)
        } else {
            capture(tabID: tabID, webView: webView, targetWidth: preferredWidth, minInterval: 0)
        }
    }
    // MARK: - UI Convenience
    public func thumbnail(for tabID: UUID) -> UIImage? {
        let key = tabID as NSUUID
        if let cached = decodedCache.object(forKey: key) {
            touch(tabID)
            return cached
        }
        guard let data = encodedStore[tabID] else { return nil }
        guard let decoded = UIImage(data: data) else {
            encodedStore[tabID] = nil
            lastCapturedAt[tabID] = nil
            bumpRevision()
            return nil
        }
        decodedCache.setObject(decoded, forKey: key, cost: estimatedImageCostBytes(decoded))
        touch(tabID)
        trimIfNeeded()
        return decoded
    }
    public func remove(tabID: UUID) {
        encodedStore[tabID] = nil
        decodedCache.removeObject(forKey: tabID as NSUUID)
        inFlight.remove(tabID)
        lastCapturedAt[tabID] = nil
        trimIfNeeded()
        bumpRevision()
    }
    // MARK: - LRU / Trim
    private func trimIfNeeded() {
        guard encodedStore.count > maxEncoded else { return }
        let overflow = encodedStore.count - maxEncoded
        let sorted = lastCapturedAt.sorted { $0.value < $1.value } // oldest first
        for (id, _) in sorted.prefix(overflow) {
            encodedStore[id] = nil
            decodedCache.removeObject(forKey: id as NSUUID)
            lastCapturedAt[id] = nil
            inFlight.remove(id)
        }
    }
    private func touch(_ id: UUID) {
        lastCapturedAt[id] = CACurrentMediaTime()
    }
    private func bumpRevision() {
        revision &+= 1
    }
    private func estimatedImageCostBytes(_ image: UIImage) -> Int {
        let scale = image.scale
        let w = Int(image.size.width * scale)
        let h = Int(image.size.height * scale)
        return max(1, w * h * 4)
    }
}
