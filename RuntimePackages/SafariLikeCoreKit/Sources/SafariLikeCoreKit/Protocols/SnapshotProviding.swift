import Foundation

/// Pure Core protocol: snapshot capability without UIImage dependency.
/// SnapshotService exposes Data/CGSize, UI layer wraps as UIImage.
public protocol SnapshotProviding: Sendable {
    /// Take a snapshot of a web view, returning Data (JPEG or PNG).
    /// - Parameters:
    ///   - webView: The WKWebView to capture
    ///   - tabID: Unique identifier for this tab
    ///   - minInterval: Minimum time in seconds before another snapshot is allowed
    ///   - targetWidth: Desired output width in points
    /// - Returns: JPEG/PNG binary data, or nil if throttled or failed
    func snapshotData(
        _ webView: WKWebView,
        tabID: UUID,
        minInterval: CFTimeInterval,
        targetWidth: CGFloat
    ) async -> Data?

    /// Query last capture time for throttling.
    func lastCaptureTime(for tabID: UUID) -> CFTimeInterval?
}

// Import WKWebView without importing UIKit
import WebKit
