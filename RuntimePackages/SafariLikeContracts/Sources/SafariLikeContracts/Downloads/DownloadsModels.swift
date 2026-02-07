import Foundation

// MARK: - Downloads (SSOT Models)

/// Lifecycle status for a download task.
public enum DownloadStatus: String, Codable, Sendable {
    case queued
    case downloading
    case paused
    case finished
    case failed
    case canceled
}

/// Persistence/privacy scope for a download.
///
/// This is intentionally defined in Contracts (not tied to WebKit profiles) so
/// BrowserCore can enforce privacy rules without importing UI/runtime layers.
public enum DownloadProfile: String, Codable, Sendable {
    case regular
    case `private`
}

/// Persistable record for a download task.
///
/// Notes:
/// - Regular downloads may be persisted and reconciled with background URLSession tasks.
/// - Private downloads must never be persisted and should be purged on scene shutdown.
public struct DownloadRecord: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var sceneID: String
    public var profile: DownloadProfile

    public var sourceURL: URL
    public var destinationURL: URL
    public var filename: String

    public var status: DownloadStatus
    public var bytesWritten: Int64
    public var bytesExpected: Int64?

    public var createdAt: Date
    public var updatedAt: Date

    public var resumeDataFilename: String?
    public var errorMessage: String?

    public init(
        id: UUID,
        sceneID: String,
        profile: DownloadProfile,
        sourceURL: URL,
        destinationURL: URL,
        filename: String,
        status: DownloadStatus,
        bytesWritten: Int64,
        bytesExpected: Int64?,
        createdAt: Date,
        updatedAt: Date,
        resumeDataFilename: String?,
        errorMessage: String?
    ) {
        self.id = id
        self.sceneID = sceneID
        self.profile = profile
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.filename = filename
        self.status = status
        self.bytesWritten = bytesWritten
        self.bytesExpected = bytesExpected
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.resumeDataFilename = resumeDataFilename
        self.errorMessage = errorMessage
    }
}

public extension DownloadRecord {
    var progress: Double {
        guard let bytesExpected, bytesExpected > 0 else { return 0 }
        return max(0, min(1, Double(bytesWritten) / Double(bytesExpected)))
    }
}

/// UI-friendly projection for in-progress downloads.
public struct DownloadActivity: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var sceneID: String
    public var profile: DownloadProfile

    public var url: URL
    public var filename: String
    public var progress: Double
    public var status: DownloadStatus
    public var errorMessage: String?

    public init(
        id: UUID,
        sceneID: String,
        profile: DownloadProfile,
        url: URL,
        filename: String,
        progress: Double,
        status: DownloadStatus,
        errorMessage: String?
    ) {
        self.id = id
        self.sceneID = sceneID
        self.profile = profile
        self.url = url
        self.filename = filename
        self.progress = progress
        self.status = status
        self.errorMessage = errorMessage
    }
}

/// Metadata for a downloaded file suitable for list UI and handoff.
public struct DownloadFile: Identifiable, Codable, Sendable, Equatable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let modifiedAt: Date
    public let sizeBytes: Int64

    public init(url: URL, name: String, modifiedAt: Date, sizeBytes: Int64) {
        self.url = url
        self.name = name
        self.modifiedAt = modifiedAt
        self.sizeBytes = sizeBytes
    }
}

// MARK: - Sharing

/// A lightweight cross-layer share payload.
///
/// UI layers can translate this into platform-specific activity items.
public struct SharePayload: Codable, Sendable, Equatable {
    public var url: URL?
    public var title: String?
    public var selectedText: String?
    public var fileURL: URL?

    public init(url: URL? = nil, title: String? = nil, selectedText: String? = nil, fileURL: URL? = nil) {
        self.url = url
        self.title = title
        self.selectedText = selectedText
        self.fileURL = fileURL
    }
}
