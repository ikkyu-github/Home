import Foundation
import CoreGraphics
import SafariLikeCoreKit
/// Per-pane web runtime context.
///
/// This is the unit of isolation for split panes:
/// - Each pane has its own WebViewPool (no direct sharing across panes)
/// - Metrics are stored per pane to allow targeted updates on rotation/resize
@MainActor
final class PaneMetrics {
    var lastContainerSize: CGSize = .zero
    var lastSafeAreaInsets: CGSize = .zero
}
@MainActor
struct PaneContext {
    let paneID: PaneID
    let webViewPool: WebViewPool
    let metrics: PaneMetrics
    init(paneID: PaneID, webViewPool: WebViewPool, metrics: PaneMetrics? = nil) {
        self.paneID = paneID
        self.webViewPool = webViewPool
        self.metrics = metrics ?? PaneMetrics()
    }
}
