import Foundation
import UIKit
import WebKit
import SafariLikeCoreKit
/// Captures and caches lightweight tab snapshots.
///
/// Threading:
/// - Call `captureSnapshot(...)` from the main actor (WKWebView requirement).
/// - Encoding/compression runs off the main thread.
@MainActor
final class SnapshotService {
    struct Budget: Equatable {
        let maxSnapshots: Int
        let maxTotalCostBytes: Int
        let maxConcurrentCaptures: Int

        static var `default`: Budget {
#if targetEnvironment(macCatalyst)
            // Desktop-class memory budget; still bounded and deterministic.
            Budget(maxSnapshots: 24, maxTotalCostBytes: 120 * 1024 * 1024, maxConcurrentCaptures: 2)
#else
            // Safari-like discipline: keep previews lightweight and bounded.
            Budget(maxSnapshots: 12, maxTotalCostBytes: 32 * 1024 * 1024, maxConcurrentCaptures: 1)
#endif
        }
    }

    private let encodeQueue = DispatchQueue(label: "SafariLikeKit.SnapshotService.encode", qos: .utility)
    // MARK: - Cache (LRU, bytes)
    private var encodedStore: [UUID: Data] = [:]
    private var lru: [UUID] = [] // most-recent first
    private var costByID: [UUID: Int] = [:]
    private var totalCostBytes: Int = 0
    // MARK: - Capture throttling
    private var inFlight: Set<UUID> = []
    private var lastCapturedAt: [UUID: CFTimeInterval] = [:]
    private var globalInFlightCount: Int = 0
    private var generation: UInt64 = 0
    // MARK: - Limits
    private let maxEncoded: Int
    private let maxTotalCostBytes: Int
    private let maxConcurrentCaptures: Int
    /// Invoked when new snapshot data is available for a tab.
    var onSnapshotUpdated: ((UUID, Data) -> Void)?

    #if DEBUG
    private var debugEvictionCount: Int = 0
    #endif

    init(budget: Budget = .default) {
        self.maxEncoded = max(1, budget.maxSnapshots)
        self.maxTotalCostBytes = max(1, budget.maxTotalCostBytes)
        self.maxConcurrentCaptures = max(1, budget.maxConcurrentCaptures)
    }

    // MARK: - Explicit Cache API
    func storeSnapshot(tabID: UUID, data: Data) {
        setSnapshotData(data, for: tabID)
        onSnapshotUpdated?(tabID, data)
    }

    func snapshot(for tabID: UUID) -> Data? {
        snapshotData(for: tabID)
    }

    func removeSnapshot(tabID: UUID) {
        clearSnapshot(for: tabID)
    }

    func clearAll() {
        generation &+= 1
        encodedStore.removeAll()
        lru.removeAll()
        costByID.removeAll()
        totalCostBytes = 0
        inFlight.removeAll()
        lastCapturedAt.removeAll()
        globalInFlightCount = 0
    }

    #if DEBUG
    struct DebugMetrics: Equatable {
        let snapshotCount: Int
        let totalCostBytes: Int
        let evictionCount: Int
        let inFlightCount: Int
    }

    func debugMetrics() -> DebugMetrics {
        DebugMetrics(
            snapshotCount: encodedStore.count,
            totalCostBytes: totalCostBytes,
            evictionCount: debugEvictionCount,
            inFlightCount: inFlight.count
        )
    }

    func debugDumpString() -> String {
        let m = debugMetrics()
        return "SnapshotService(count=\(m.snapshotCount) bytes=\(m.totalCostBytes) evictions=\(m.evictionCount) inFlight=\(m.inFlightCount) budgetCount=\(maxEncoded) budgetBytes=\(maxTotalCostBytes))"
    }
    #endif
    func snapshotData(for tabID: UUID) -> Data? {
        guard let data = encodedStore[tabID] else { return nil }
        touch(tabID)
        return data
    }
    func clearSnapshot(for tabID: UUID) {
        remove(tabID)
        lastCapturedAt[tabID] = nil
    }
    /// Capture a snapshot for a tab without blocking the main thread.
    ///
    /// - Note: `WKWebView.takeSnapshot` must be initiated on the main thread.
    func captureSnapshot(
        tabID: UUID,
        webView: WKWebView,
        targetWidth: CGFloat = 520,
        minInterval: CFTimeInterval = 1.0,
        jpegQuality: CGFloat = 0.65
    ) {
        let gen = generation
        let now = CACurrentMediaTime()
        if let last = lastCapturedAt[tabID], (now - last) < minInterval {
            return
        }
        guard inFlight.contains(tabID) == false else { return }
        guard globalInFlightCount < maxConcurrentCaptures else { return }
        inFlight.insert(tabID)
        globalInFlightCount += 1
        lastCapturedAt[tabID] = now
        let config = WKSnapshotConfiguration()
        config.snapshotWidth = targetWidth as NSNumber
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.generation == gen else { return }

                guard let image else {
                    self.finishCapture(tabID: tabID)
                    return
                }

                self.encodeQueue.async { [weak self] in
                    guard let self else { return }
                    guard let data = image.jpegData(compressionQuality: jpegQuality) else {
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            guard self.generation == gen else { return }
                            self.finishCapture(tabID: tabID)
                        }
                        return
                    }

                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        guard self.generation == gen else { return }
                        self.setSnapshotData(data, for: tabID)
                        self.onSnapshotUpdated?(tabID, data)
                        self.finishCapture(tabID: tabID)
                    }
                }
            }
        }
    }
    func captureSnapshotOnLifecycleTransition(
        tabID: UUID,
        from: TabLifecycleState,
        to: TabLifecycleState,
        webView: WKWebView
    ) {
        guard from == .active else { return }
        guard to == .suspended || to == .discarded else { return }
        captureSnapshot(tabID: tabID, webView: webView, minInterval: 0)
    }
    // MARK: - Internals
    private func finishCapture(tabID: UUID) {
        inFlight.remove(tabID)
        globalInFlightCount = max(0, globalInFlightCount - 1)
    }
    private func setSnapshotData(_ data: Data, for tabID: UUID) {
        let newCost = max(1, data.count)
        if let old = costByID[tabID] {
            totalCostBytes = max(0, totalCostBytes - old)
        }
        encodedStore[tabID] = data
        costByID[tabID] = newCost
        totalCostBytes += newCost
        touch(tabID)
        trimIfNeeded()

        #if DEBUG
        assert(encodedStore.count <= maxEncoded, "SnapshotService exceeded snapshot-count budget. \(debugDumpString())")
        assert(totalCostBytes <= maxTotalCostBytes, "SnapshotService exceeded bytes budget. \(debugDumpString())")
        #endif
    }
    private func remove(_ tabID: UUID) {
        if let oldCost = costByID[tabID] {
            totalCostBytes = max(0, totalCostBytes - oldCost)
        }
        encodedStore[tabID] = nil
        costByID[tabID] = nil
        lru.removeAll { $0 == tabID }
        inFlight.remove(tabID)
    }
    private func touch(_ tabID: UUID) {
        lru.removeAll { $0 == tabID }
        lru.insert(tabID, at: 0)
    }
    private func trimIfNeeded() {
        while encodedStore.count > maxEncoded || totalCostBytes > maxTotalCostBytes {
            guard let victim = lru.last else { break }
            remove(victim)
            #if DEBUG
            debugEvictionCount &+= 1
            #endif
        }
    }
}
