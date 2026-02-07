import Foundation
import SafariLikeCoreKit

@MainActor
extension AppLifecycleCoordinator {
    private static let parityReportDefaultsKey = "SafariLike.Debug.ParityReportOnForeground"
    private static var didPrintParityReportThisProcess: Bool = false

    /// DEBUG-only parity report that can be triggered without UI.
    ///
    /// Set `UserDefaults.standard[SafariLike.Debug.ParityReportOnForeground] = true` to print on the next foreground.
    public func debugPrintSafariParityReportIfRequested() async {
        guard Self.didPrintParityReportThisProcess == false else { return }
        guard UserDefaults.standard.bool(forKey: Self.parityReportDefaultsKey) else { return }
        Self.didPrintParityReportThisProcess = true

        let report = await debugSafariParityReport()
        Diagnostics.logInfo(report, subsystem: .runtime, category: "SafariParity")
        print(report)
    }

    public func debugSafariParityReport() async -> String {
        let date = ISO8601DateFormatter().string(from: Date())
        var lines: [String] = []
        lines.append("=== Safari Parity Report (DEBUG) ===")
        lines.append("generatedAt: \(date)")
        lines.append("scenesRegistered: \(runtimeRegistry.contexts.count)")
        lines.append("totalLiveWebViewsAllPools: \(WebViewPool.totalLiveWebViewCount())")

        let metrics = await CoreKitMetrics.snapshot()
        lines.append("coreKitMetrics.webViewConstructedCount: \(metrics.webViewConstructedCount)")
        lines.append("coreKitMetrics.poolBorrow: alreadyLeased=\(metrics.poolBorrowAlreadyLeasedCount) reusedSameTab=\(metrics.poolBorrowReusedSameTabCount) reusedOtherTab=\(metrics.poolBorrowReusedOtherTabCount) createdNew=\(metrics.poolBorrowCreatedNewCount)")
        lines.append("coreKitMetrics.poolReturnLeaseCount: \(metrics.poolReturnLeaseCount)")
        lines.append("coreKitMetrics.poolDiscardTabCount: \(metrics.poolDiscardTabCount)")
        lines.append("coreKitMetrics.poolOversubscribedCount: \(metrics.poolOversubscribedCount)")
        lines.append("coreKitMetrics.poolEvictions: idle=\(metrics.poolEvictedIdleCount) leased=\(metrics.poolEvictedLeasedCount)")
        lines.append("coreKitMetrics.tabActivation: attempts=\(metrics.tabActivationAttemptCount) suppressed=\(metrics.tabActivationSuppressedCount) guardRejected=\(metrics.tabActivationGuardRejectedCount) missingPool=\(metrics.tabActivationMissingPoolSuppressedCount) succeeded=\(metrics.tabActivationSucceededCount)")
        lines.append("coreKitMetrics.tabDeactivated: warm=\(metrics.tabDeactivatedWarmCount) cold=\(metrics.tabDeactivatedColdCount)")

        if metrics.countsByPoolLabel.isEmpty == false {
            let byPool = metrics.countsByPoolLabel
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            lines.append("coreKitMetrics.webViewConstructedByPoolLabel: \(byPool)")
        }

        lines.append("-- per scene --")
        for (sceneID, context) in runtimeRegistry.contexts.sorted(by: { $0.key.raw < $1.key.raw }) {
            lines.append("sceneID: \(sceneID.raw)")
            lines.append("  windowID: \(context.windowID)")

            // Regular profile.
            lines.append("  regular.tabRegistry: aliveStores=\(context.tabRegistry.aliveStoresCount) activeWebViews=\(context.tabRegistry.activeWebViewsCount) budgets(maxAlive=\(context.tabRegistry.debugMaxAliveWebViewsLimit) maxConcurrent=\(context.tabRegistry.debugMaxConcurrentViewsLimit))")
            lines.append("  regular.webViewPool: label=\(context.webViewPool.label) live=\(context.webViewPool.liveWebViewCount) maxLive=\(context.webViewPool.maxLiveWebViews)")

            // Private profile.
            lines.append("  private.tabRegistry: aliveStores=\(context.privateTabRegistry.aliveStoresCount) activeWebViews=\(context.privateTabRegistry.activeWebViewsCount) budgets(maxAlive=\(context.privateTabRegistry.debugMaxAliveWebViewsLimit) maxConcurrent=\(context.privateTabRegistry.debugMaxConcurrentViewsLimit))")
            lines.append("  private.webViewPool: label=\(context.privateWebViewPool.label) live=\(context.privateWebViewPool.liveWebViewCount) maxLive=\(context.privateWebViewPool.maxLiveWebViews)")
        }

        lines.append("-- static checks (run in repo) --")
        lines.append("layering + WKWebView construction sites: Dev/Tools/Scripts/safari_parity_check.sh")

        return lines.joined(separator: "\n")
    }
}
