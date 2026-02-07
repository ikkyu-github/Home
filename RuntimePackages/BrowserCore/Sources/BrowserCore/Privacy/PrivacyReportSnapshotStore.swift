import Foundation
import SafariLikeContracts

public enum PrivacyReportSnapshotPersistence: Sendable, Equatable {
    case disk(filename: String)
    case memory

    public static let `default` = PrivacyReportSnapshotPersistence.disk(filename: "privacy-report-snapshot-v1.json")
}

/// Stores the most recent privacy report snapshot (regular profile only).
public actor PrivacyReportSnapshotStore {
    private let persistence: PrivacyReportSnapshotPersistence
    private let fileStore: JSONFileStoreActor

    private var cached: PrivacyReportSnapshot?

    public init(
        persistence: PrivacyReportSnapshotPersistence = .default,
        fileStore: JSONFileStoreActor = JSONFileStoreActor()
    ) {
        self.persistence = persistence
        self.fileStore = fileStore
    }

    public func bootstrap() async {
        guard case let .disk(filename) = persistence else { return }
        let loaded: PrivacyReportSnapshot? = await fileStore.load(filename: filename, defaultValue: nil)
        cached = loaded
    }

    public func latestSnapshot() -> PrivacyReportSnapshot? {
        cached
    }

    public func setLatestSnapshot(_ snapshot: PrivacyReportSnapshot?) async {
        cached = snapshot
        guard case let .disk(filename) = persistence else { return }
        await fileStore.save(filename: filename, value: snapshot)
    }
}
