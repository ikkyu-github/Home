import Foundation
import CoreGraphics

/// A read-only, serializable-ish record of WKWebView attachment/visibility "reality".
///
/// Notes:
/// - This type intentionally does not import UIKit/SwiftUI/WebKit.
/// - `isVisible` should be computed at the capture site (UIKit) using view properties
///   such as `isHidden == false` and `alpha > 0.01`.
public struct WebViewRealitySnapshot: Equatable, Sendable {
    public let tabID: UUID

    /// A best-effort identifier for the specific web view instance.
    ///
    /// Derived from `ObjectIdentifier` at the capture site. This is intended for
    /// short-lived correlation/deduping (not stable across launches).
    public let webViewObjectID: UInt64

    public let hasSuperview: Bool
    public let hasWindow: Bool
    public let frame: CGRect

    /// Convenience field captured alongside `frame`.
    public let isFrameNonZero: Bool

    /// Capture-time visibility hint (e.g. `isHidden == false && alpha > 0.01`).
    public let isVisible: Bool

    public let timestamp: Date

    public var isRealityReady: Bool {
        hasSuperview && hasWindow && isFrameNonZero && isVisible
    }

    public init(
        tabID: UUID,
        webViewObjectID: UInt64,
        hasSuperview: Bool,
        hasWindow: Bool,
        frame: CGRect,
        isVisible: Bool,
        timestamp: Date = Date()
    ) {
        self.tabID = tabID
        self.webViewObjectID = webViewObjectID
        self.hasSuperview = hasSuperview
        self.hasWindow = hasWindow
        self.frame = frame
        self.isFrameNonZero = frame.isEmpty == false
        self.isVisible = isVisible
        self.timestamp = timestamp
    }

    /// Convenience helper for generating a snapshot `webViewObjectID` from any object.
    ///
    /// This avoids importing WebKit in CoreKit; call with a `WKWebView` instance from UI code.
    @inlinable
    public static func objectID(for object: AnyObject) -> UInt64 {
        UInt64(UInt(bitPattern: ObjectIdentifier(object)))
    }
}
