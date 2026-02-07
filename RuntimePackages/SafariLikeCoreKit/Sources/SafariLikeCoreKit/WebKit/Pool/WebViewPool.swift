// ARCH-AUDIT(2026-01-22): UIKit dependency (canImport) inside WebKit pool. Candidate for WebEngineAdapter; core should not depend on UIKit/SwiftUI.

import Foundation
import CoreGraphics
import WebKit

@MainActor
public final class WebViewPool {
    public nonisolated static let DEFAULT_MAX_LIVE_WEBVIEWS: Int = 2
    public nonisolated static let MAX_LIVE_WEBVIEWS: Int = DEFAULT_MAX_LIVE_WEBVIEWS

    @MainActor
    public protocol BudgetDelegate: AnyObject {
        func webViewPool(_ pool: WebViewPool, evictTabID: UUID, reason: EvictionReason)
    }

    public enum EvictionReason: Sendable {
        case maxLiveExceeded
    }

    /// A lease represents temporary ownership of a live `WKWebView` by a tab.
    ///
    /// Rules:
    /// - Only active/visible tabs should hold a lease.
    /// - Background tabs must return the lease (detached from UI).
    public struct WebViewLease {
        public let webView: WKWebView
        public let leaseID: UUID
        public let tabID: UUID

        public init(webView: WKWebView, leaseID: UUID, tabID: UUID) {
            self.webView = webView
            self.leaseID = leaseID
            self.tabID = tabID
        }
    }

    private static let poolTable: NSHashTable<WebViewPool> = NSHashTable.weakObjects()

    public enum Notifications {
        /// Posted whenever the pool's live-tab set changes.
        ///
        /// userInfo:
        /// - liveCount: Int
        /// - liveTabIDs: [String] (UUID strings)
        public static let didChange = Notification.Name("SafariLike.webviewPool.didChange")

        /// Posted when an acquire would exceed the live limit.
        ///
        /// userInfo:
        /// - tabID: String (UUID)
        /// - liveCount: Int
        public static let oversubscribed = Notification.Name("SafariLike.webviewPool.oversubscribed")
    }

    /// Centralized WKWebView construction point.
    ///
    /// Architecture guardrail: all WKWebView constructors in the codebase
    /// should route through this method so creation is auditable and enforceable.
    @MainActor
    public static func makeWebView(configuration: WKWebViewConfiguration) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.safariLikeMarkAllocatedByWebViewPool()
        return webView
    }

    @inline(__always)
    static func assertWebViewAllocatedByPool(
        _ webView: WKWebView,
        fileID: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        #if DEBUG
        guard webView.safariLikeWasAllocatedByWebViewPool else {
            assertionFailure(
                "[WebViewPool] WKWebView missing allocation tag. This indicates a WKWebView was created outside WebViewPool.makeWebView(configuration:). caller=\(fileID):\(line) \(function)",
                file: fileID,
                line: line
            )
            return
        }
        #endif
    }

    /// A human-readable label for diagnostics (e.g. "window.normal.primary").
    public let label: String

    /// Unique, per-instance identity token.
    ///
    /// Used to prevent `WKWebView` instances from crossing pool (scene/window) boundaries.
    public let poolID: UUID

    /// Human-readable pool owner identity used for diagnostics.
    ///
    /// Default is `label`; callers may provide a distinct identity if needed.
    public let ownerIdentity: String

    /// Maximum number of live WKWebViews this pool should allow.
    ///
    /// Note: "live" here means the underlying `WKWebView` exists in-memory for a tab,
    /// regardless of whether it is currently attached to UI.
    public var maxLiveWebViews: Int

    public weak var budgetDelegate: (any BudgetDelegate)?

    private struct LeaseEntry {
        var webView: WKWebView
        var leaseID: UUID
        var priority: TabPriority
        var lastTouchedAt: CFTimeInterval
    }

    private struct IdleEntry {
        var webView: WKWebView
        var lastReturnedAt: CFTimeInterval
        /// The last leaseID that was active for this tab.
        /// Used only for debugging/diagnostics.
        var lastLeaseID: UUID
        var priority: TabPriority
    }

    private var leasedByTabID: [UUID: LeaseEntry] = [:]
    private var idleByTabID: [UUID: IdleEntry] = [:]

    #if DEBUG
    private var debugTotalCreatedCount: Int = 0

    public struct DebugMetrics: Sendable, Equatable {
        public let label: String
        public let ownerIdentity: String
        public let poolID: UUID
        public let maxLiveWebViews: Int
        public let liveCount: Int
        public let leasedCount: Int
        public let idleCount: Int
        public let totalCreatedCount: Int
    }
    #endif

    #if DEBUG
    public enum DebugBorrowResult: Sendable, Equatable {
        case alreadyLeased
        case reusedFromSameTab
        case reusedFromOtherTab(otherTabID: UUID)
        case createdNew
    }

    private var debugLastBorrowResultByTabID: [UUID: DebugBorrowResult] = [:]

    public struct DebugTabEntry: Sendable {
        public enum State: Sendable {
            case leased
            case idle
        }

        public let tabID: UUID
        public let state: State
        public let leaseID: UUID?
        public let priority: TabPriority
        public let lastTouchedAt: CFTimeInterval
    }

    public struct DebugSnapshot: Sendable {
        public let label: String
        public let maxLiveWebViews: Int
        public let leasedCount: Int
        public let idleCount: Int
        public let entriesByRecency: [DebugTabEntry]
    }
    #endif

    // Legacy protection API used by TabRegistry.
    // Protected tabs are treated as "do not evict".
    private var protectedTabIDs: Set<UUID> = []

    // Legacy hint used by TabRegistry.
    private var activeTabID: UUID?

    /// Factory used when the pool must create a new `WKWebView`.
    ///
    /// Note: higher layers may want to inject a configuration tuned for their website data store,
    /// content blockers, etc. For now we keep a safe default.
    private let makeWebView: @MainActor () -> WKWebView

    public init(
        label: String = "pool",
        ownerIdentity: String? = nil,
        maxLiveWebViews: Int = WebViewPool.DEFAULT_MAX_LIVE_WEBVIEWS,
        makeWebView: @escaping @MainActor () -> WKWebView = {
            let config = EngineController.shared.makeWebViewConfiguration(profile: .regular)
            return WebViewPool.makeWebView(configuration: config)
        }
    ) {
        self.poolID = UUID()
        self.label = label
        self.ownerIdentity = ownerIdentity ?? label
        self.maxLiveWebViews = max(1, maxLiveWebViews)
        self.makeWebView = makeWebView
        Self.poolTable.add(self)
    }

    @MainActor
    private func makeOwnedWebViewFromFactory() -> WKWebView {
        let created = makeWebView()
        if !ensureOwnedByThisPool(created) {
            // Extremely defensive: if an injected factory produces a WebView that fails ownership checks,
            // fall back to a known-safe construction path.
            let config = EngineController.shared.makeWebViewConfiguration(profile: .regular)
            return makeOwnedWebView(configuration: config)
        }
        #if DEBUG
        debugTotalCreatedCount += 1
        #endif
        return created
    }

    @MainActor
    private func makeOwnedWebView(configuration: WKWebViewConfiguration) -> WKWebView {
        let created = Self.makeWebView(configuration: configuration)
        created.safariLikeMarkOwnedByWebViewPool(poolID: poolID, ownerIdentity: ownerIdentity)
        #if DEBUG
        debugTotalCreatedCount += 1
        #endif
        return created
    }

    @MainActor
    private func ensureOwnedByThisPool(_ webView: WKWebView) -> Bool {
        Self.assertWebViewAllocatedByPool(webView)
        if let existingOwner = webView.safariLikeOwningWebViewPoolID {
            if existingOwner == poolID { return true }
            #if DEBUG
            assertionFailure("[WebViewPool] Cross-pool WKWebView reuse blocked. webViewOwner=\(webView.safariLikeOwningWebViewPoolOwnerIdentity ?? "<unknown>") thisPool=\(ownerIdentity)")
            #endif
            return false
        }

        // Back-compat: older instances may only have the allocator tag.
        if webView.safariLikeWasAllocatedByWebViewPool {
            webView.safariLikeMarkOwnedByWebViewPool(poolID: poolID, ownerIdentity: ownerIdentity)
            return true
        }

        Self.assertWebViewAllocatedByPool(webView)
        return false
    }

    /// Aggregate count across all `WebViewPool` instances in-process.
    public static func totalLiveWebViewCount() -> Int {
        poolTable.allObjects.reduce(0) { $0 + $1.liveWebViewCount }
    }

    /// Current number of live WKWebViews owned/tracked by the pool.
    public var liveWebViewCount: Int { leasedByTabID.count + idleByTabID.count }

    /// Snapshot of tab IDs that currently have a live WebView in the pool.
    /// Includes both active leases and idle (returned) entries.
    public var liveTabIDsSnapshot: [UUID] {
        // Most recently touched first.
        let leased = leasedByTabID.mapValues { $0.lastTouchedAt }
        let idle = idleByTabID.mapValues { $0.lastReturnedAt }
        let merged = leased.merging(idle) { max($0, $1) }
        return merged
            .sorted(by: { $0.value > $1.value })
            .map { $0.key }
    }

    /// Convenience API that matches the higher-level rendering abstraction.
    @discardableResult
    public func acquire(for tabID: UUID, context: WebContext) -> WKWebView {
        acquireWebView(for: tabID, context: context)
    }

    /// Convenience API that matches the higher-level rendering abstraction.
    public func release(tabID: UUID) {
        releaseTab(tabID)
    }

    public func acquireWebView(for tabID: UUID, context: WebContext) -> WKWebView {
        // Compatibility shim:
        // - WebContext owns the configuration + privacy separation.
        // - WebViewPool owns *construction* and lease tracking for budgeting.
        // - The WebView is created lazily at activation time.
        if let existing = context.webView {
            Self.assertWebViewAllocatedByPool(existing)
            if let existingOwner = existing.safariLikeOwningWebViewPoolID, existingOwner != poolID {
                #if DEBUG
                assertionFailure("[WebViewPool] Existing WKWebView belongs to a different pool; discarding to enforce scene isolation. existingOwner=\(existing.safariLikeOwningWebViewPoolOwnerIdentity ?? "<unknown>") thisPool=\(ownerIdentity)")
                #endif
                context.discardAttachedWebViewForReparenting()
            } else if existing.safariLikeOwningWebViewPoolID == nil {
                // Back-compat: tag existing instance on first use.
                _ = ensureOwnedByThisPool(existing)
            }
        }
        let webView = context.ensureWebViewCreated { [configuration = context.configuration] in
            let created = self.makeOwnedWebView(configuration: configuration)
            CoreKitMetrics.recordWebViewConstructed(poolLabel: self.label)
            return created
        }
        if !ensureOwnedByThisPool(webView) {
            // Deterministic recovery: create a fresh, correctly-owned instance.
            context.discardAttachedWebViewForReparenting()
            let recreated = context.ensureWebViewCreated { [configuration = context.configuration] in
                let created = self.makeOwnedWebView(configuration: configuration)
                CoreKitMetrics.recordWebViewConstructed(poolLabel: self.label)
                return created
            }
            _ = borrowExistingWebView(recreated, tabID: tabID, priority: .foreground)
            return recreated
        }
        _ = borrowExistingWebView(webView, tabID: tabID, priority: .foreground)
        return webView
    }

    public func acquireWebView(for tabID: UUID, configuration: WKWebViewConfiguration) -> WKWebView {
        // Legacy API: keep for compatibility, but creation must happen via WebContext.
        let context = WebContext(configuration: configuration, privacyMode: .regular)
        return acquireWebView(for: tabID, context: context)
    }

    // MARK: - Lease API

    public func borrow(tabID: UUID, priority: TabPriority) -> WebViewLease {
        // If the caller marks this tab as discarded, discard immediately and do not vend a lease.
        // This is best-effort: higher layers should avoid calling borrow for discarded tabs.
        if priority == .discarded {
            discard(tabID: tabID)
        }

        // If already leased, just update priority/recency.
        if var leased = leasedByTabID[tabID] {
            leased.priority = priority
            leased.lastTouchedAt = CACurrentMediaTime()
            leasedByTabID[tabID] = leased
            CoreKitMetrics.recordPoolBorrowAlreadyLeased()
            #if DEBUG
            debugLastBorrowResultByTabID[tabID] = .alreadyLeased
            #endif
            return WebViewLease(webView: leased.webView, leaseID: leased.leaseID, tabID: tabID)
        }

        // Prefer reusing the tab's own returned WebView if it exists.
        if let idle = idleByTabID.removeValue(forKey: tabID) {
            let leaseID = UUID()
            leasedByTabID[tabID] = LeaseEntry(
                webView: idle.webView,
                leaseID: leaseID,
                priority: priority,
                lastTouchedAt: CACurrentMediaTime()
            )
            #if DEBUG
            debugLastBorrowResultByTabID[tabID] = .reusedFromSameTab
            #endif
            CoreKitMetrics.recordPoolBorrowReusedSameTab()
            enforceMaxLiveBudget(acquiringTabID: tabID)
            notifyDidChange()
            return WebViewLease(webView: idle.webView, leaseID: leaseID, tabID: tabID)
        }

        // Otherwise, reuse the most-recently-returned idle WebView from another tab.
        if let (otherTabID, idle) = idleByTabID.max(by: { lhs, rhs in
            if lhs.value.lastReturnedAt != rhs.value.lastReturnedAt {
                return lhs.value.lastReturnedAt < rhs.value.lastReturnedAt
            }
            // Deterministic tie-breaker.
            return lhs.key.uuidString < rhs.key.uuidString
        }) {
            idleByTabID.removeValue(forKey: otherTabID)
            let leaseID = UUID()
            leasedByTabID[tabID] = LeaseEntry(
                webView: idle.webView,
                leaseID: leaseID,
                priority: priority,
                lastTouchedAt: CACurrentMediaTime()
            )
            #if DEBUG
            debugLastBorrowResultByTabID[tabID] = .reusedFromOtherTab(otherTabID: otherTabID)
            #endif
            CoreKitMetrics.recordPoolBorrowReusedOtherTab()
            enforceMaxLiveBudget(acquiringTabID: tabID)
            notifyDidChange()
            return WebViewLease(webView: idle.webView, leaseID: leaseID, tabID: tabID)
        }

        // No idle WebViews: create a new one if budget allows, otherwise evict.
        ensureCapacityForBorrow(acquiringTabID: tabID)
        let created = makeOwnedWebViewFromFactory()
        CoreKitMetrics.recordWebViewConstructed(poolLabel: label)
        let leaseID = UUID()
        leasedByTabID[tabID] = LeaseEntry(
            webView: created,
            leaseID: leaseID,
            priority: priority,
            lastTouchedAt: CACurrentMediaTime()
        )
        #if DEBUG
        debugLastBorrowResultByTabID[tabID] = .createdNew
        #endif
        CoreKitMetrics.recordPoolBorrowCreatedNew()
        enforceMaxLiveBudget(acquiringTabID: tabID)
        notifyDidChange()
        return WebViewLease(webView: created, leaseID: leaseID, tabID: tabID)
    }

    #if DEBUG
    public func debugMetrics() -> DebugMetrics {
        DebugMetrics(
            label: label,
            ownerIdentity: ownerIdentity,
            poolID: poolID,
            maxLiveWebViews: maxLiveWebViews,
            liveCount: liveWebViewCount,
            leasedCount: leasedByTabID.count,
            idleCount: idleByTabID.count,
            totalCreatedCount: debugTotalCreatedCount
        )
    }

    public func debugDescribeState() -> String {
        let m = debugMetrics()
        let snapshot = debugSnapshot()
        let ids = snapshot.entriesByRecency.map { entry in
            let state: String = (entry.state == .leased) ? "leased" : "idle"
            return "\(entry.tabID.uuidString.prefix(8)):\(state):\(entry.priority)"
        }.joined(separator: ",")
        return "WebViewPool(label=\(m.label) owner=\(m.ownerIdentity) poolID=\(m.poolID) maxLive=\(m.maxLiveWebViews) live=\(m.liveCount) leased=\(m.leasedCount) idle=\(m.idleCount) created=\(m.totalCreatedCount)) tabs=[\(ids)]"
    }

    public func debugLastBorrowResult(tabID: UUID) -> DebugBorrowResult? {
        debugLastBorrowResultByTabID[tabID]
    }

    public func debugSnapshot() -> DebugSnapshot {
        let leasedEntries: [DebugTabEntry] = leasedByTabID.map { tabID, entry in
            DebugTabEntry(
                tabID: tabID,
                state: .leased,
                leaseID: entry.leaseID,
                priority: entry.priority,
                lastTouchedAt: entry.lastTouchedAt
            )
        }

        let idleEntries: [DebugTabEntry] = idleByTabID.map { tabID, entry in
            DebugTabEntry(
                tabID: tabID,
                state: .idle,
                leaseID: entry.lastLeaseID,
                priority: entry.priority,
                lastTouchedAt: entry.lastReturnedAt
            )
        }

        let merged = (leasedEntries + idleEntries).sorted(by: { $0.lastTouchedAt > $1.lastTouchedAt })
        return DebugSnapshot(
            label: label,
            maxLiveWebViews: maxLiveWebViews,
            leasedCount: leasedByTabID.count,
            idleCount: idleByTabID.count,
            entriesByRecency: merged
        )
    }

    public nonisolated static func debugAllPoolsSnapshot() async -> [DebugSnapshot] {
        await MainActor.run {
            poolTable.allObjects.map { $0.debugSnapshot() }
        }
    }
    #endif

    public func returnLease(_ lease: WebViewLease) {
        guard let entry = leasedByTabID[lease.tabID] else { return }
        guard entry.leaseID == lease.leaseID else { return }
        CoreKitMetrics.recordPoolReturnLease()

        leasedByTabID.removeValue(forKey: lease.tabID)
        idleByTabID[lease.tabID] = IdleEntry(
            webView: entry.webView,
            lastReturnedAt: CACurrentMediaTime(),
            lastLeaseID: entry.leaseID,
            priority: entry.priority
        )

        enforceMaxLiveBudget(acquiringTabID: nil)
        notifyDidChange()
    }

    /// Discard any WebView associated with this tab (leased or idle).
    ///
    /// This is the aggressive path used when a tab is closed/evicted.
    public func discard(tabID: UUID) {
        var didDiscard = false
        if let leased = leasedByTabID.removeValue(forKey: tabID) {
            leased.webView.stopLoading()
            didDiscard = true
        }
        if let idle = idleByTabID.removeValue(forKey: tabID) {
            idle.webView.stopLoading()
            didDiscard = true
        }
        if didDiscard {
            CoreKitMetrics.recordPoolDiscardTab()
        }
        notifyDidChange()
    }

    // MARK: - Legacy shims (TabRegistry compatibility)

    /// Legacy API: mark a tab as active in the pool.
    ///
    /// New semantics:
    /// - Records the active tab ID (used as an anti-eviction hint).
    /// - Treats the tab as foreground priority.
    public func makeTabActive(_ tabID: UUID) async {
        activeTabID = tabID
        protectedTabIDs.insert(tabID)
        setTabPriority(tabID, priority: .foreground)
    }

    /// Legacy API: set the protected (non-evictable) tab set.
    public func setProtectedTabIDs(_ ids: Set<UUID>) {
        protectedTabIDs = ids
    }

    /// Update a tab's eviction priority without changing lease ownership.
    ///
    /// This is intentionally safe to call even when higher layers still own the underlying
    /// `WKWebView` (e.g. during the migration where `WebContext` owns a per-tab web view).
    public func setTabPriority(_ tabID: UUID, priority: TabPriority) {
        if var leased = leasedByTabID[tabID] {
            leased.priority = priority
            leased.lastTouchedAt = CACurrentMediaTime()
            leasedByTabID[tabID] = leased
            notifyDidChange()
        }
    }

    public func releaseTab(_ tabID: UUID) {
        // Compatibility shim:
        // Treat "release" as returning a live lease to the pool.
        if let entry = leasedByTabID[tabID] {
            let lease = WebViewLease(webView: entry.webView, leaseID: entry.leaseID, tabID: tabID)
            returnLease(lease)
            return
        }
        // If not leased, ensure we stop tracking the tab.
        if idleByTabID.removeValue(forKey: tabID) != nil {
            notifyDidChange()
        }
    }

    /// Release a tab's WebView aggressively (do not keep it in the engine idle pool).
    ///
    /// This corresponds to a heavier "freeze" level where we prefer reclaiming memory.
    public func invalidateTab(_ tabID: UUID) {
        // Compatibility shim:
        // Treat "invalidate" as discarding the tab's WebView.
        discard(tabID: tabID)
    }

    public func snapshotAndFreezeTab(_ tabID: UUID) async {
        // Higher layers perform snapshots; pool only releases.
        releaseTab(tabID)
    }

    private func notifyDidChange() {
        NotificationCenter.default.post(
            name: Notifications.didChange,
            object: self,
            userInfo: [
                "liveCount": liveWebViewCount,
                "liveTabIDs": liveTabIDsSnapshot.map { $0.uuidString },
                "poolLabel": label,
                "totalLiveCount": Self.totalLiveWebViewCount()
            ]
        )
    }

    private func borrowExistingWebView(_ webView: WKWebView, tabID: UUID, priority: TabPriority) -> WebViewLease {
        Self.assertWebViewAllocatedByPool(webView)
        if !ensureOwnedByThisPool(webView) {
            // Should not happen (caller should recover earlier), but remain safe.
            let created = makeOwnedWebViewFromFactory()
            return borrowExistingWebView(created, tabID: tabID, priority: priority)
        }
        // Replace any prior tracking for this tab (best-effort).
        idleByTabID.removeValue(forKey: tabID)
        let leaseID = UUID()
        leasedByTabID[tabID] = LeaseEntry(
            webView: webView,
            leaseID: leaseID,
            priority: priority,
            lastTouchedAt: CACurrentMediaTime()
        )

        if liveWebViewCount >= maxLiveWebViews {
            NotificationCenter.default.post(
                name: Notifications.oversubscribed,
                object: self,
                userInfo: [
                    "tabID": tabID.uuidString,
                    "liveCount": liveWebViewCount,
                    "poolLabel": label,
                    "totalLiveCount": Self.totalLiveWebViewCount()
                ]
            )
            CoreKitMetrics.recordPoolOversubscribed()
        }

        enforceMaxLiveBudget(acquiringTabID: tabID)
        notifyDidChange()
        return WebViewLease(webView: webView, leaseID: leaseID, tabID: tabID)
    }

    private func ensureCapacityForBorrow(acquiringTabID: UUID) {
        guard liveWebViewCount >= maxLiveWebViews else { return }
        enforceMaxLiveBudget(acquiringTabID: acquiringTabID)
    }

    private func enforceMaxLiveBudget(acquiringTabID: UUID?) {
        guard liveWebViewCount > maxLiveWebViews else { return }

        func evictionRank(_ p: TabPriority) -> Int {
            switch p {
            case .discarded: return 0
            case .background: return 1
            case .foreground: return 2
            }
        }

        // Prefer evicting least-recently-used background tabs first.
        while liveWebViewCount > maxLiveWebViews {
            // 1) Evict LRU idle/background tabs first.
            if let (tabID, _) = idleByTabID
                .filter({ !protectedTabIDs.contains($0.key) })
                .min(by: { lhs, rhs in
                    let lRank = evictionRank(lhs.value.priority)
                    let rRank = evictionRank(rhs.value.priority)
                    if lRank != rRank { return lRank < rRank }
                    if lhs.value.lastReturnedAt != rhs.value.lastReturnedAt {
                        return lhs.value.lastReturnedAt < rhs.value.lastReturnedAt
                    }
                    // Deterministic tie-breaker.
                    return lhs.key.uuidString < rhs.key.uuidString
                }) {
                idleByTabID.removeValue(forKey: tabID)
                CoreKitMetrics.recordPoolEvictedIdle()
                budgetDelegate?.webViewPool(self, evictTabID: tabID, reason: .maxLiveExceeded)
                continue
            }

            // If we're still oversubscribed, we have too many active leases.
            // Evict the lowest-priority, least-recently-used lease (best-effort).
            var candidates = leasedByTabID
            if let acquiringTabID {
                candidates.removeValue(forKey: acquiringTabID)
            }
            if let activeTabID {
                candidates.removeValue(forKey: activeTabID)
            }
            candidates = candidates.filter { !protectedTabIDs.contains($0.key) }

            guard let (tabID, _) = candidates.min(by: { lhs, rhs in
                let lRank = evictionRank(lhs.value.priority)
                let rRank = evictionRank(rhs.value.priority)
                if lRank != rRank { return lRank < rRank }
                if lhs.value.lastTouchedAt != rhs.value.lastTouchedAt {
                    return lhs.value.lastTouchedAt < rhs.value.lastTouchedAt
                }
                // Deterministic tie-breaker.
                return lhs.key.uuidString < rhs.key.uuidString
            }) else {
                break
            }
            leasedByTabID.removeValue(forKey: tabID)
            CoreKitMetrics.recordPoolEvictedLeased()
            budgetDelegate?.webViewPool(self, evictTabID: tabID, reason: .maxLiveExceeded)
        }

        #if DEBUG
        if liveWebViewCount > maxLiveWebViews {
            assertionFailure(
                "[WebViewPool] budget enforcement failed: live=\(liveWebViewCount) max=\(maxLiveWebViews). acquiringTabID=\(acquiringTabID?.uuidString ?? "<nil>") state=\(debugDescribeState())"
            )
        }
        #endif

        notifyDidChange()
    }
}
