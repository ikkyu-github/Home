import Foundation
import CoreGraphics
import SafariLikeCoreKit
import WebKit
/// Per-tab render controller.
///
/// This is intentionally a thin wrapper around existing lifecycle systems:
/// - WebView ownership/activation lives in CoreKit (`TabRegistry` / `TabWebStore`).
/// - Snapshot bytes are owned by `SnapshotService`.
/// - Higher-level policy (2-view budget, discard policy) still lives in TabManager.
@MainActor
final class TabRenderController {
    let tabID: UUID
    private weak var manager: TabManager?
    private(set) var state: TabRenderState = .suspended
    init(tabID: UUID, manager: TabManager) {
        self.tabID = tabID
        self.manager = manager
    }
    /// Transition into a snapshot-only state without resizing/splitting the WKWebView.
    ///
    /// Behavior:
    /// - Capture a snapshot (best-effort) if a live webview exists and no recent snapshot is available.
    /// - Detach/release the WKWebView using CoreKit's lifecycle (`freezeWebView`).
    func enterSnapshotOnly(
        reason: String,
        targetWidth: CGFloat = 520,
        minInterval: CFTimeInterval = 2.0
    ) {
        guard let manager else { return }
        guard let store = manager.currentTabRegistry.existingStore(for: tabID) else {
            state = .snapshotOnly
            return
        }
        if store.webViewHandle != nil {
            let hasSnapshot: Bool = manager.state.tabs.first(where: { $0.id == tabID })?.hasSnapshot == true
            if hasSnapshot == false, let webView = store.webViewHandle?.webView {
                manager.snapshotService.captureSnapshot(
                    tabID: tabID,
                    webView: webView,
                    targetWidth: targetWidth,
                    minInterval: minInterval,
                    jpegQuality: 0.65
                )
                RuntimeMetrics.shared.increment(.snapshotCaptured)
            }
            manager.requestDeactivateWebView(tabID: tabID, mode: .warm, reason: "renderBudget.freeze.\(reason)")
            RuntimeMetrics.shared.increment(.renderBudgetFreeze)
            RuntimeMetrics.shared.increment(.webViewDeactivated)
            Diagnostics.logInfo(
                "[RenderBudget] freeze tabID=\(tabID) reason=\(reason)",
                subsystem: .runtime,
                category: "RenderBudget"
            )
        }
        state = .snapshotOnly
    }
}
