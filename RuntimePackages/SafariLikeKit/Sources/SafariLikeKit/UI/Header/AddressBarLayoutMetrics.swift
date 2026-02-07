import CoreGraphics
import SwiftUI
import SafariLikeCoreKit
/// Shared address bar layout metrics for iPhone/iPad/split-pane.
///
/// Computed from environment inputs to keep the address bar consistent across layouts.
struct AddressBarLayoutMetrics: Equatable {
    var collapsedHeight: CGFloat
    var expandedHeight: CGFloat
    var collapsedVerticalPadding: CGFloat
    var expandedVerticalPadding: CGFloat
    var cornerRadius: CGFloat
    var horizontalPadding: CGFloat
    var iconWidth: CGFloat
    var interItemSpacing: CGFloat
    static func current(
        layoutMode: BrowserLayoutMode,
        dynamicTypeSize: DynamicTypeSize
    ) -> AddressBarLayoutMetrics {
        let isRegular = (layoutMode == .tabletLandscape)
        let isAX = dynamicTypeSize.isAccessibilitySize
        // Base sizes tuned to feel Safari-like.
        let collapsedHeight: CGFloat = isAX ? 40 : 34
        let expandedHeight: CGFloat = isAX ? 52 : (isRegular ? 46 : 44)
        let collapsedVerticalPadding: CGFloat = isAX ? 7 : 6
        let expandedVerticalPadding: CGFloat = isAX ? 11 : 9
        return AddressBarLayoutMetrics(
            collapsedHeight: collapsedHeight,
            expandedHeight: expandedHeight,
            collapsedVerticalPadding: collapsedVerticalPadding,
            expandedVerticalPadding: expandedVerticalPadding,
            cornerRadius: 14,
            horizontalPadding: 12,
            iconWidth: 14,
            interItemSpacing: 8
        )
    }
}
