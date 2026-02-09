import SwiftUI
import CoreGraphics

/// Safari-like Interaction Contract: single geometry truth for web viewport vs chrome vs overlays.
///
/// Coordinate space:
/// - All rects are in the container coordinate space of `BrowserView`'s `GeometryReader`.
/// - `safeAreaInsets` must come from `BrowserLayoutSnapshot.effectiveSafeAreaInsets`.
/// - Chrome heights must come from `BrowserLayoutSnapshot` (SSOT).
internal enum BrowserContentViewportContract {
    static func contentViewportRect(containerSize: CGSize, viewportInsets: EdgeInsets) -> CGRect {
        let x = max(0, viewportInsets.leading)
        let y = max(0, viewportInsets.top)
        let width = max(0, containerSize.width - viewportInsets.leading - viewportInsets.trailing)
        let height = max(0, containerSize.height - viewportInsets.top - viewportInsets.bottom)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func chromeTopRect(containerSize: CGSize, safeAreaInsets: EdgeInsets, chromeTopHeight: CGFloat) -> CGRect {
        let y = max(0, safeAreaInsets.top)
        let height = max(0, chromeTopHeight)
        return CGRect(x: 0, y: y, width: containerSize.width, height: height)
    }

    /// Rect for the tappable bottom chrome (excludes keyboard lift).
    static func chromeBottomRect(
        containerSize: CGSize,
        safeAreaInsets: EdgeInsets,
        chromeBottomHeight: CGFloat,
        keyboardLift: CGFloat
    ) -> CGRect {
        let height = max(0, chromeBottomHeight)
        let y = max(0, containerSize.height - safeAreaInsets.bottom - keyboardLift - height)
        return CGRect(x: 0, y: y, width: containerSize.width, height: height)
    }

    static func keyboardLiftRect(containerSize: CGSize, safeAreaInsets: EdgeInsets, keyboardLift: CGFloat) -> CGRect {
        let height = max(0, keyboardLift)
        let y = max(0, containerSize.height - safeAreaInsets.bottom - height)
        return CGRect(x: 0, y: y, width: containerSize.width, height: height)
    }
}
