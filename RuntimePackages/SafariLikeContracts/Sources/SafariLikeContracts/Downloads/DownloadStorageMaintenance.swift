import Foundation

public struct DownloadStorageMetrics: Sendable, Equatable {
    public var persistentFileCount: Int
    public var persistentTotalBytes: Int64
    public var temporaryFileCount: Int
    public var temporaryTotalBytes: Int64

    public init(
        persistentFileCount: Int,
        persistentTotalBytes: Int64,
        temporaryFileCount: Int,
        temporaryTotalBytes: Int64
    ) {
        self.persistentFileCount = persistentFileCount
        self.persistentTotalBytes = persistentTotalBytes
        self.temporaryFileCount = temporaryFileCount
        self.temporaryTotalBytes = temporaryTotalBytes
    }
}

/// Optional maintenance interface for download storage.
///
/// `BrowserCore.DownloadCenter` can call this on bootstrap and/or periodically to enforce
/// storage budgets and to emit debug metrics.
public protocol DownloadStorageMaintaining: Sendable {
    /// Applies best-effort pruning based on implementation policy.
    ///
    /// Returns metrics after pruning.
    func pruneStorage(now: Date) -> DownloadStorageMetrics

    /// Returns current storage metrics.
    func storageMetrics(now: Date) -> DownloadStorageMetrics
}
