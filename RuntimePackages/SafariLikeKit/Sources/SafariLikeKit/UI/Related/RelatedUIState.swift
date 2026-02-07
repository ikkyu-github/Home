import Combine
import CoreGraphics
import SwiftUI
import SafariLikeCoreKit
/// UI chrome state for the Related (Companion) surface.
///
/// Sizing-only state (sidebar ratio + popup height) that survives
/// active tab/pane switches without being reset.
@MainActor
final class RelatedUIState: ObservableObject {
    static let popupHeightFractionSnapPoints: [CGFloat] = [0.35, 0.50, 0.65]
    @Published var sidebarRatio: CGFloat = 0.30
    @Published var popupHeightFraction: CGFloat = SplitBrowserConstants.relatedSnapMid
    static func snappedPopupHeightFraction(_ fraction: CGFloat) -> CGFloat {
        let clamped = min(max(fraction, 0), 1)
        return snap(clamped, anchors: popupHeightFractionSnapPoints)
    }
    private static func snap(_ value: CGFloat, anchors: [CGFloat]) -> CGFloat {
        anchors.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
    }
}
