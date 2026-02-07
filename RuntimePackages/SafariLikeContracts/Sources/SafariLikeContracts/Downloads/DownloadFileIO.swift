import Foundation

/// File-system boundary for downloads.
///
/// Rationale:
/// - `BrowserCore` owns download state and task coordination, but does not directly touch
///   concrete filesystem policies (Documents directory selection, folder creation, collisions).
/// - Platform/UI layers provide a concrete implementation (typically using `FileManager`).
///
/// Privacy:
/// - Implementations must not persist anything for `.private` downloads.
/// - Callers should avoid logging URLs/paths.
public protocol DownloadFileIO: Sendable {
    /// Returns a destination URL for a new download.
    ///
    /// Implementations should:
    /// - Ensure the downloads directory exists.
    /// - Resolve name collisions.
    /// - Avoid persisting private downloads to durable locations.
    func makeDestinationURL(for filename: String, profile: DownloadProfile) -> URL

    /// Lists existing downloaded files for UI presentation.
    func listFiles() -> [DownloadFile]

    /// Persists resume data for a specific download id.
    ///
    /// Implementations may return a filename token (relative name) suitable for later retrieval.
    func writeResumeData(_ data: Data, for id: UUID, profile: DownloadProfile) throws -> String

    /// Loads previously persisted resume data.
    func readResumeData(named name: String, profile: DownloadProfile) throws -> Data

    /// Deletes previously persisted resume data.
    func deleteResumeData(named name: String, profile: DownloadProfile) throws

    /// Moves a completed download from a temporary URL into its final destination.
    ///
    /// Implementations should ensure parent directories exist and may replace existing files.
    func commitDownloadedTempFile(from tempURL: URL, to destinationURL: URL) throws
}

public extension DownloadFileIO {
    /// Backwards-compatible convenience overload: defaults to `.regular`.
    func makeDestinationURL(for filename: String) -> URL {
        makeDestinationURL(for: filename, profile: .regular)
    }

    /// Backwards-compatible convenience overload: defaults to `.regular`.
    func writeResumeData(_ data: Data, for id: UUID) throws -> String {
        try writeResumeData(data, for: id, profile: .regular)
    }

    /// Backwards-compatible convenience overload: defaults to `.regular`.
    func readResumeData(named name: String) throws -> Data {
        try readResumeData(named: name, profile: .regular)
    }

    /// Backwards-compatible convenience overload: defaults to `.regular`.
    func deleteResumeData(named name: String) throws {
        try deleteResumeData(named: name, profile: .regular)
    }
}
