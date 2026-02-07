import Foundation
import SafariLikeContracts

public enum SiteSettingsPersistence: Sendable, Equatable {
    case disk(filename: String)
    case memory

    public static let `default` = SiteSettingsPersistence.disk(filename: "site-settings-v1.json")
}

/// Safari-grade per-site settings store.
///
/// Stores user decisions keyed by site (best-effort eTLD+1) and permission type.
///
/// Threading: actor-isolated.
public actor SiteSettingsStore {
    private let persistence: SiteSettingsPersistence
    private let fileStore: JSONFileStoreActor

    private var snapshot: SiteSettingsSnapshot

    // Fast index for lookups.
    private var indexBySiteKey: [String: [PermissionType: SitePermissionRecord]] = [:]

    public init(
        persistence: SiteSettingsPersistence = .default,
        fileStore: JSONFileStoreActor = JSONFileStoreActor()
    ) {
        self.persistence = persistence
        self.fileStore = fileStore
        self.snapshot = SiteSettingsSnapshot()
    }

    /// Loads persisted snapshot if `persistence` is `.disk`.
    public func bootstrap() async {
        guard case let .disk(filename) = persistence else { return }
        let loaded = await fileStore.load(filename: filename, defaultValue: SiteSettingsSnapshot())
        snapshot = loaded
        rebuildIndex()
    }

    public func currentSnapshot() -> SiteSettingsSnapshot {
        snapshot
    }

    public func setGlobalDefault(_ decision: PermissionDecision, for type: PermissionType, source: PermissionSource = .user) async {
        snapshot.globalDefaults[type] = decision
        await persistIfNeeded()
    }

    public func clearAllSiteRecords() async {
        snapshot.records.removeAll()
        rebuildIndex()
        await persistIfNeeded()
    }

    public func clearSiteRecords(for siteKey: SiteKey) async {
        let key = siteKey.storageKey
        snapshot.records.removeAll { $0.siteKey.storageKey == key }
        rebuildIndex()
        await persistIfNeeded()
    }

    public func record(for siteKey: SiteKey, type: PermissionType) -> SitePermissionRecord? {
        indexBySiteKey[siteKey.storageKey]?[type]
    }

    public func effectiveDecision(for siteKey: SiteKey, type: PermissionType) -> PermissionDecision {
        if let record = record(for: siteKey, type: type) {
            return record.decision
        }
        if let global = snapshot.globalDefaults[type] {
            return global
        }
        return type.safeFallbackDecision
    }

    public func setDecision(
        _ decision: PermissionDecision,
        for siteKey: SiteKey,
        type: PermissionType,
        source: PermissionSource = .user
    ) async {
        let key = siteKey.storageKey

        var perSite = indexBySiteKey[key] ?? [:]
        var record = perSite[type] ?? SitePermissionRecord(siteKey: siteKey, permissionType: type, decision: decision, source: source)
        record.decision = decision
        record.updatedAt = Date()
        record.source = source
        perSite[type] = record
        indexBySiteKey[key] = perSite

        // Update snapshot records list (replace or append).
        if let idx = snapshot.records.firstIndex(where: { $0.siteKey.storageKey == key && $0.permissionType == type }) {
            snapshot.records[idx] = record
        } else {
            snapshot.records.append(record)
        }

        await persistIfNeeded()
    }

    public func diagnosticsSummary() -> String {
        let siteCount = indexBySiteKey.keys.count
        let recordCount = snapshot.records.count
        return "SiteSettingsStore sites=\(siteCount) records=\(recordCount) schema=\(snapshot.schemaVersion)"
    }

    // MARK: - Statistics (Deterministic Snapshot)

    public struct StatisticsSnapshot: Sendable, Hashable {
        public let permissionSummaries: [PermissionSummaryItem]

        public init(permissionSummaries: [PermissionSummaryItem]) {
            self.permissionSummaries = permissionSummaries
        }
    }

    /// Returns a deterministic snapshot suitable for UI/diagnostics.
    ///
    /// - Note: Uses stored per-site decisions only (does not expand global defaults).
    public func statisticsSnapshot() -> StatisticsSnapshot {
        var byType: [PermissionType: PermissionDecisionCounts] = [:]

        for record in snapshot.records {
            var counts = byType[record.permissionType] ?? PermissionDecisionCounts()
            switch record.decision {
            case .allow:
                counts.allow += 1
            case .deny:
                counts.deny += 1
            case .ask:
                counts.ask += 1

            @unknown default:
                assertionFailure("Unhandled PermissionDecision: \(record.decision)")
                counts.ask += 1
            }
            byType[record.permissionType] = counts
        }

        let summaries: [PermissionSummaryItem] = PermissionType.allCases
            .map { type in
                PermissionSummaryItem(permissionType: type, counts: byType[type] ?? PermissionDecisionCounts())
            }

        return StatisticsSnapshot(permissionSummaries: summaries)
    }

    // MARK: - Private

    private func rebuildIndex() {
        indexBySiteKey.removeAll(keepingCapacity: true)
        for record in snapshot.records {
            let key = record.siteKey.storageKey
            var perSite = indexBySiteKey[key] ?? [:]
            perSite[record.permissionType] = record
            indexBySiteKey[key] = perSite
        }
    }

    private func persistIfNeeded() async {
        guard case let .disk(filename) = persistence else { return }
        await fileStore.save(filename: filename, value: snapshot)
    }
}
