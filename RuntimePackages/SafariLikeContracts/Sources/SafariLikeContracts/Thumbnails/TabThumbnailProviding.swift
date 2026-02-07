import Foundation

/// Protocol for providing thumbnail data without UIKit dependency.
///
/// This is a cross-layer contract (UI implementations, core consumers).
public protocol TabThumbnailProviding: AnyObject {
    func thumbnailData(for tabID: UUID) -> Data?
    func setThumbnailData(_ data: Data?, for tabID: UUID)
}
