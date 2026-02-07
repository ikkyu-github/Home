import Foundation
import UIKit
import SafariLikeCoreKit
import SafariLikeContracts
import WebKit
@MainActor
final class DiscardController {
    struct Metrics: Sendable {
        let trigger: TabDiscardTrigger
        let candidates: Int
        let discarded: Int
    }
    private weak var tabManager: TabManager?
    private let config: SafariLikeCoreKit.TabDiscardConfig = .default
    private let smartPolicy: any SafariLikeCoreKit.SmartDiscardPolicy = SafariLikeCoreKit.DefaultSmartDiscardPolicy()
    private var notificationTokens: [NSObjectProtocol] = []
    private var lastSignals: [UUID: TabEngagementModel] = [:]
    private var lastMediaHintAtBySiteKey: [String: Date] = [:]
    private var backgroundEnteredAt: Date?
    private var sweepTask: Task<Void, Never>?
    var onMetrics: ((Metrics) -> Void)?
    init(tabManager: TabManager) {
        self.tabManager = tabManager
    }
    func start() {
        stop()
        notificationTokens.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.backgroundEnteredAt = Date()
                    self.scheduleBackgroundLongCheckIfNeeded()
                }
            }
        )
        notificationTokens.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.backgroundEnteredAt = nil
                }
            }
        )
        notificationTokens.append(
            NotificationCenter.default.addObserver(
                forName: Notification.Name("SafariLike.webviewPool.oversubscribed"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.apply(trigger: .webViewOversubscribed)
                }
            }
        )
        sweepTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let count = self.tabManager?.sessionStore.tabs.count ?? 0
                if count >= self.config.highTabCountThreshold {
                    self.apply(trigger: .tabCountHigh(count: count))
                }
                self.apply(trigger: .tabInactiveSweep)
                do {
                    try await Task.sleep(nanoseconds: UInt64(max(1, self.config.sweepInterval) * 1_000_000_000))
                } catch {
                    break
                }
            }
        }
    }
    func stop() {
        sweepTask?.cancel()
        sweepTask = nil
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()
    }
    func noteVisible(tabID: UUID, isVisible: Bool) {
        guard isVisible else { return }
        var s = lastSignals[tabID] ?? TabEngagementModel(tabID: tabID)
        s.lastVisibleAt = Date()
        lastSignals[tabID] = s
    }
    func noteInteraction(tabID: UUID) {
        var s = lastSignals[tabID] ?? TabEngagementModel(tabID: tabID)
        s.lastInteractionAt = Date()
        lastSignals[tabID] = s
    }
    func protectedTabIDsForActivePanes() -> Set<UUID> {
        guard let tabManager else { return [] }
        var protected = Set(tabManager.currentVisiblePaneTabIDs())
        switch tabManager.activeBindingState {
        case .bound(let id), .binding(let id):
            protected.insert(id)
        case .unbound, .unbinding:
            break
        }
        return protected
    }
    func apply(trigger: TabDiscardTrigger) {
        Task { @MainActor [weak self] in
            await self?.applySiteAware(trigger: trigger)
        }
    }
    private func applySiteAware(trigger: TabDiscardTrigger) async {
        guard let tabManager else { return }
        LaunchTracer.shared.mark("discard.begin", "trigger=\(String(describing: trigger))")
        let now = Date()
        let protected = protectedTabIDsForActivePanes()
        let focusedActiveID: UUID? = {
            guard tabManager.isSplitPanePresentationActive else { return tabManager.activeTabID }
            return (tabManager.activePane == .right) ? tabManager.rightTabID : tabManager.leftTabID
        }()
        let tabStatesByID: [UUID: TabState] = Dictionary(uniqueKeysWithValues: tabManager.tabs.map { ($0.id, $0) })
        let sessionTabByID: [UUID: BrowserTab] = Dictionary(uniqueKeysWithValues: tabManager.sessionStore.tabs.map { ($0.id, $0) })
        struct Input {
            let tabID: UUID
            let sessionTab: BrowserTab
            let lastActiveAt: Date
            let siteKey: String
            let url: URL?
            let isPlayingMedia: Bool
        }
        var inputs: [Input] = []
        inputs.reserveCapacity(tabManager.currentTabRegistry.aliveTabIDs.count)
        for tabID in tabManager.currentTabRegistry.aliveTabIDs {
            guard let sessionTab = sessionTabByID[tabID] else { continue }
            let lastActiveAt = tabStatesByID[tabID]?.lastActiveAt ?? sessionTab.lastVisitedAt
            var s = lastSignals[tabID] ?? TabEngagementModel(tabID: tabID)
            if s.lastVisibleAt == nil { s.lastVisibleAt = lastActiveAt }
            if s.lastInteractionAt == nil { s.lastInteractionAt = lastActiveAt }
            s.isPrivate = tabManager.isPrivateMode
            if let store = tabManager.currentTabRegistry.existingStore(for: tabID) {
                let hasLive = store.webViewHandle != nil
                s.estimatedMemoryCost = hasLive ? 90 : 8
                s.backForwardDepth = (store.state.canGoBack ? 1 : 0) + (store.state.canGoForward ? 1 : 0)
            } else {
                s.estimatedMemoryCost = 2
                s.backForwardDepth = 0
            }
            lastSignals[tabID] = s
            let url = URL(string: sessionTab.urlString)
            let siteKey: String = {
                guard let url else { return "unknown" }
                return SiteHeuristicsModel.normalizeSiteKey(from: url)
            }()
            inputs.append(.init(
                tabID: tabID,
                sessionTab: sessionTab,
                lastActiveAt: lastActiveAt,
                siteKey: siteKey,
                url: url,
                isPlayingMedia: s.isPlayingMedia
            ))
        }
        // Batch policy lookup (async, actor-backed). This yields the main actor while waiting.
        let uniqueSiteKeys = Array(Set(inputs.map { $0.siteKey }))
        let policiesBySiteKey = await SiteHeuristicsRuntime.collector.computePolicies(for: uniqueSiteKeys)
        // Feed media playback hints (throttled) to heuristics.
        let mediaThrottle: TimeInterval = 10 * 60
        for item in inputs where item.isPlayingMedia {
            let last = lastMediaHintAtBySiteKey[item.siteKey] ?? .distantPast
            if now.timeIntervalSince(last) >= mediaThrottle {
                lastMediaHintAtBySiteKey[item.siteKey] = now
                Task {
                    await SiteHeuristicsRuntime.collector.recordMediaHeavySite(siteKey: item.siteKey)
                }
            }
        }
        let pressure = pressureLevel(for: trigger)
        var signals: [SafariLikeContracts.TabDiscardSignals] = []
        signals.reserveCapacity(inputs.count)
        for item in inputs {
            let tabID = item.tabID
            let sessionTab = item.sessionTab
            let lastActiveAt = item.lastActiveAt
            let s = lastSignals[tabID] ?? TabEngagementModel(tabID: tabID)
            let lastInteraction = s.lastInteractionAt ?? lastActiveAt
            let lastVisible = s.lastVisibleAt
            let isForegroundRecently = lastVisible.map { now.timeIntervalSince($0) < 45 } ?? false
            let sitePolicy = policiesBySiteKey[item.siteKey] ?? .default
            let siteCategory = classifySiteCategory(url: item.url, sitePolicy: sitePolicy)
            // Site policy bias: encourage discarding problematic sites earlier.
            let policyBias = max(-20, min(20, (sitePolicy.discardAggressiveness - 2) * 10))
            let memoryCost = max(0, (s.estimatedMemoryCost) + policyBias)
            let isActive = (focusedActiveID == tabID) || (tabManager.activeTabID == tabID)
            signals.append(.init(
                tabID: tabID,
                lastInteractionTime: lastInteraction,
                isPinned: sessionTab.isPinned || sessionTab.isUserLocked,
                isPlayingMedia: s.isPlayingMedia,
                isEditingForm: s.hasPendingFormEdits,
                memoryCostEstimate: memoryCost,
                siteCategory: siteCategory,
                navigationDepth: max(0, s.backForwardDepth),
                isForegroundRecently: isForegroundRecently,
                isActive: isActive,
                lastCommittedURL: item.url
            ))
        }
        let plan = smartPolicy.plan(tabs: signals, pressure: pressure, now: now)
        var actions: [(tabID: UUID, target: TabDiscardLevel)] = []
        actions.reserveCapacity(config.maxActionsPerApply)
        let suspendLevel: TabDiscardLevel = (pressure == .critical) ? .freezeCold : .detachKeepSnapshot
        func appendActions(from ids: [UUID], target: TabDiscardLevel) {
            for id in ids {
                guard actions.count < config.maxActionsPerApply else { return }
                // 2-view policy + hard guards.
                guard protected.contains(id) == false else { continue }
                actions.append((id, target))
            }
        }
        if pressure == .critical {
            appendActions(from: plan.discardOrder, target: .discardKeepToken)
            appendActions(from: plan.suspendOrder, target: suspendLevel)
        } else {
            appendActions(from: plan.suspendOrder, target: suspendLevel)
            appendActions(from: plan.discardOrder, target: .discardKeepToken)
        }
        var appliedCount = 0
        for action in actions {
            await apply(targetLevel: action.target, tabID: action.tabID, tabManager: tabManager)
            appliedCount += 1
        }
        onMetrics?(.init(trigger: trigger, candidates: signals.count, discarded: appliedCount))
        LaunchTracer.shared.mark("discard.end", "trigger=\(String(describing: trigger));candidates=\(signals.count);discarded=\(appliedCount)")
    }
    private func pressureLevel(for trigger: TabDiscardTrigger) -> SafariLikeCoreKit.SmartDiscardPressureLevel {
        switch trigger {
        case .memoryWarning(.critical), .thermalState(.critical):
            return .critical
        case .memoryWarning(.warning),
             .webViewOversubscribed,
             .tabCountHigh(count: _),
             .appBackgroundedLong(duration: _),
             .thermalState(.serious):
            return .warning
        case .tabInactiveSweep:
            return .normal
        @unknown default:
            return .warning
        }
    }
    private func classifySiteCategory(url: URL?, sitePolicy: SitePolicy) -> SafariLikeContracts.SiteCategory {
        if sitePolicy.discardAggressiveness == 0 {
            // Treat sensitive sites as "never discard" by pushing them into the most conservative bucket.
            return .video
        }
        guard let host = url?.host?.lowercased(), host.isEmpty == false else {
            return .unknown
        }
        if host.contains("youtube") || host.contains("twitch") || host.contains("netflix") || host.contains("primevideo") || host.contains("disney") || host.contains("spotify") || host.contains("soundcloud") {
            return .video
        }
        if host.contains("docs") || host.contains("notion") || host.contains("drive.google") || host.contains("office") || host.contains("pdf") {
            return .doc
        }
        if host.contains("twitter") || host.contains("x.com") || host.contains("facebook") || host.contains("instagram") || host.contains("tiktok") || host.contains("reddit") {
            return .social
        }
        return .unknown
    }
    private func scheduleBackgroundLongCheckIfNeeded() {
        guard let enteredAt = backgroundEnteredAt else { return }
        let threshold = max(1, config.backgroundLongThreshold)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(threshold * 1_000_000_000))
            } catch {
                return
            }
            guard UIApplication.shared.applicationState == .background else { return }
            guard let stillEnteredAt = self.backgroundEnteredAt else { return }
            let duration = max(0, Date().timeIntervalSince(stillEnteredAt))
            if stillEnteredAt == enteredAt {
                self.apply(trigger: .appBackgroundedLong(duration: duration))
            }
        }
    }
    private func apply(targetLevel: TabDiscardLevel, tabID: UUID, tabManager: TabManager) async {
        let protected = protectedTabIDsForActivePanes()
        if protected.contains(tabID) { return }
        // Hard safety gates: never discard/suspend protected tabs.
        if let sessionTab = tabManager.sessionStore.tabs.first(where: { $0.id == tabID }) {
            if sessionTab.isPinned || sessionTab.isUserLocked { return }
        }
        if let s = lastSignals[tabID] {
            if s.isPlayingMedia || s.hasPendingFormEdits { return }
        }
        switch targetLevel {
        case .keepAttached:
            return
        case .detachKeepSnapshot:
            await detach(tabID: tabID, tabManager: tabManager, mode: .warm, discardLevel: .detachKeepSnapshot)
        case .freezeCold:
            await detach(tabID: tabID, tabManager: tabManager, mode: .cold, discardLevel: .freezeCold)
        case .discardKeepToken:
            await unload(tabID: tabID, tabManager: tabManager)
        @unknown default:
            return
        }
    }
    private func detach(
        tabID: UUID,
        tabManager: TabManager,
        mode: SafariLikeCoreKit.TabRegistry.WebViewDetachMode,
        discardLevel: TabDiscardLevel
    ) async {
        guard let store = tabManager.currentTabRegistry.existingStore(for: tabID) else { return }
        guard store.webViewHandle?.isAlive == true else { return }
        if let webView = store.webViewHandle?.webView {
            tabManager.snapshotService.captureSnapshotOnLifecycleTransition(
                tabID: tabID,
                from: .active,
                to: .suspended,
                webView: webView
            )
        }
        await tabManager.pluginHost?.tabWillFreeze(tabID: tabID)
        tabManager.requestDeactivateWebView(tabID: tabID, mode: mode, reason: "discard.\(discardLevel)")
        RuntimeMetrics.shared.increment(.webViewDeactivated)
        tabManager.destroyRuntime(for: tabID)
        tabManager.sessionStore.updateTabResourceState(
            id: tabID,
            lifecycleState: .suspended,
            discardLevel: discardLevel,
            clearRestoreToken: true
        )
        tabManager.setLifecycle(tabID: tabID, lifecycle: .suspended, runtimeAttachment: .detached)
    }
    private func unload(tabID: UUID, tabManager: TabManager) async {
        var token: TabRestoreToken?
        if let store = tabManager.currentTabRegistry.existingStore(for: tabID), let webView = store.webViewHandle?.webView {
            tabManager.snapshotService.captureSnapshotOnLifecycleTransition(
                tabID: tabID,
                from: .active,
                to: .discarded,
                webView: webView
            )
            let urlStringFromWebView = webView.url?.absoluteString
            let urlStringFromSession = tabManager.sessionStore.tabs.first(where: { $0.id == tabID })?.urlString
            let urlString = (urlStringFromWebView ?? urlStringFromSession)?.trimmingCharacters(in: .whitespacesAndNewlines)
            var scrollY: Double?
            do {
                let raw = try await webView.evaluateJavaScriptAsync("window.scrollY")
                if let d = raw as? Double {
                    scrollY = d
                } else if let i = raw as? Int {
                    scrollY = Double(i)
                } else if let n = raw as? NSNumber {
                    scrollY = n.doubleValue
                }
            } catch {
                // Best-effort only.
                scrollY = nil
            }
            // Lightweight history summary (best-effort; does not imply we can rehydrate WebKit's full list).
            let back = webView.backForwardList.backList.suffix(25).map { item in
                BackForwardListSummary.Item(url: item.url, title: item.title)
            }
            let forward = webView.backForwardList.forwardList.prefix(25).map { item in
                BackForwardListSummary.Item(url: item.url, title: item.title)
            }
            let current: BackForwardListSummary.Item? = webView.backForwardList.currentItem.map {
                BackForwardListSummary.Item(url: $0.url, title: $0.title)
            }
            let summary = BackForwardListSummary(back: Array(back), current: current, forward: Array(forward))
            if let urlString, urlString.isEmpty == false {
                token = TabRestoreToken(
                    lastCommittedURLString: urlString,
                    scrollY: scrollY,
                    backForwardListSummary: summary
                )
            }
        }
        // If we couldn't capture from WebKit (e.g. already torn down), fall back to the persisted URL.
        if token == nil,
           let urlString = tabManager.sessionStore.tabs.first(where: { $0.id == tabID })?.urlString
            .trimmingCharacters(in: .whitespacesAndNewlines),
           urlString.isEmpty == false {
            token = TabRestoreToken(lastCommittedURLString: urlString)
        }
        await tabManager.pluginHost?.tabWillFreeze(tabID: tabID)
        await tabManager.pluginHost?.tabWillEvict(tabID: tabID)
        await tabManager.currentTabRegistry.remove(tabID: tabID)
        tabManager.destroyRuntime(for: tabID)
        tabManager.sessionStore.updateTabResourceState(
            id: tabID,
            lifecycleState: .discarded,
            discardLevel: .discardKeepToken,
            restoreToken: token
        )
        tabManager.setLifecycle(tabID: tabID, lifecycle: .discarded, runtimeAttachment: .detached)
    }
}
