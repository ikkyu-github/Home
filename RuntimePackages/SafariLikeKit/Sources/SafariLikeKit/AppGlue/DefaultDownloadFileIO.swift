import Foundation
import SafariLikeContracts

/// Default on-device filesystem implementation for downloads.
///
/// Exposed from SafariLikeKit so the App layer can depend only on SafariLikeKit + SafariLikeContracts.
public struct DefaultDownloadFileIO: DownloadFileIO, DownloadStorageMaintaining, Sendable {
    private struct FileManagerBox: @unchecked Sendable {
        let fileManager: FileManager
    }

    public struct Options: Sendable {
        /// Optional override for durable (regular-mode) downloads root.
        public var persistentRootDirectory: URL?

        /// Optional override for ephemeral (private-mode) downloads root.
        public var temporaryRootDirectory: URL?

        public var persistentDownloadsFolderName: String
        public var temporaryDownloadsFolderName: String
        public var resumeDataFolderName: String

        /// Best-effort budget for durable downloads.
        public var persistentMaxFileCount: Int
        /// Best-effort budget for durable downloads.
        public var persistentMaxTotalBytes: Int64?
        /// Best-effort maximum age for ephemeral files.
        public var temporaryMaxAge: TimeInterval

        public init(
            persistentRootDirectory: URL? = nil,
            temporaryRootDirectory: URL? = nil,
            persistentDownloadsFolderName: String = "Downloads",
            temporaryDownloadsFolderName: String = "DownloadsTemp",
            resumeDataFolderName: String = ".resume-data",
            persistentMaxFileCount: Int = 200,
            persistentMaxTotalBytes: Int64? = 512 * 1024 * 1024,
            temporaryMaxAge: TimeInterval = 24 * 60 * 60
        ) {
            self.persistentRootDirectory = persistentRootDirectory
            self.temporaryRootDirectory = temporaryRootDirectory
            self.persistentDownloadsFolderName = persistentDownloadsFolderName
            self.temporaryDownloadsFolderName = temporaryDownloadsFolderName
            self.resumeDataFolderName = resumeDataFolderName
            self.persistentMaxFileCount = persistentMaxFileCount
            self.persistentMaxTotalBytes = persistentMaxTotalBytes
            self.temporaryMaxAge = temporaryMaxAge
        }
    }

    private let options: Options
    private let fileManagerBox: FileManagerBox

    private var fileManager: FileManager { fileManagerBox.fileManager }

    public init(options: Options = .init(), fileManager: FileManager = .default) {
        self.options = options
        self.fileManagerBox = FileManagerBox(fileManager: fileManager)
    }

    public func makeDestinationURL(for filename: String, profile: DownloadProfile) -> URL {
        let sanitized = sanitizeFilename(filename)
        let base = downloadsDirectoryURL(profile: profile)
        let candidate = base.appendingPathComponent(sanitized)
        if !fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        let ext = candidate.pathExtension
        let stem = candidate.deletingPathExtension().lastPathComponent
        var counter = 2
        while true {
            let name = ext.isEmpty ? "\(stem)-\(counter)" : "\(stem)-\(counter).\(ext)"
            let url = base.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: url.path) {
                return url
            }
            counter += 1
        }
    }

    public func listFiles() -> [DownloadFile] {
        // Only list durable (regular) downloads.
        let dir = downloadsDirectoryURL(profile: .regular)
        guard let urls = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let mapped: [DownloadFile] = urls.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let modified = values?.contentModificationDate ?? Date.distantPast
            let size = Int64(values?.fileSize ?? 0)
            return DownloadFile(url: url, name: url.lastPathComponent, modifiedAt: modified, sizeBytes: size)
        }

        return mapped.sorted(by: { $0.modifiedAt > $1.modifiedAt })
    }

    public func writeResumeData(_ data: Data, for id: UUID, profile: DownloadProfile) throws -> String {
        let name = "\(id.uuidString).resume"
        let url = resumeDataDirectoryURL(profile: profile).appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return name
    }

    public func readResumeData(named name: String, profile: DownloadProfile) throws -> Data {
        let url = resumeDataDirectoryURL(profile: profile).appendingPathComponent(name)
        return try Data(contentsOf: url)
    }

    public func deleteResumeData(named name: String, profile: DownloadProfile) throws {
        let url = resumeDataDirectoryURL(profile: profile).appendingPathComponent(name)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    public func commitDownloadedTempFile(from tempURL: URL, to destinationURL: URL) throws {
        let parent = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: tempURL, to: destinationURL)
    }

    // MARK: - Paths

    private func downloadsDirectoryURL(profile: DownloadProfile) -> URL {
        switch profile {
        case .regular:
            if let root = options.persistentRootDirectory {
                let dir = root.appendingPathComponent(options.persistentDownloadsFolderName, isDirectory: true)
                ensureDirectoryExists(dir)
                return dir
            }

            if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let dir = appSupport.appendingPathComponent(options.persistentDownloadsFolderName, isDirectory: true)
                ensureDirectoryExists(dir)
                return dir
            }

            if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let dir = docs.appendingPathComponent(options.persistentDownloadsFolderName, isDirectory: true)
                ensureDirectoryExists(dir)
                return dir
            }

            return fileManager.temporaryDirectory

        case .private:
            if let root = options.temporaryRootDirectory {
                let dir = root.appendingPathComponent(options.temporaryDownloadsFolderName, isDirectory: true)
                ensureDirectoryExists(dir)
                return dir
            }

            if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let dir = caches.appendingPathComponent(options.temporaryDownloadsFolderName, isDirectory: true)
                ensureDirectoryExists(dir)
                return dir
            }

            let dir = fileManager.temporaryDirectory.appendingPathComponent(options.temporaryDownloadsFolderName, isDirectory: true)
            ensureDirectoryExists(dir)
            return dir

        @unknown default:
            assertionFailure("Unhandled DownloadProfile: \(profile)")
            return fileManager.temporaryDirectory
        }
    }

    private func resumeDataDirectoryURL(profile: DownloadProfile) -> URL {
        let base = downloadsDirectoryURL(profile: profile).appendingPathComponent(options.resumeDataFolderName, isDirectory: true)
        ensureDirectoryExists(base)
        return base
    }

    private func ensureDirectoryExists(_ url: URL) {
        if fileManager.fileExists(atPath: url.path) { return }
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    private func sanitizeFilename(_ filename: String) -> String {
        // Prevent path traversal and ensure the resulting filename is safe for sandbox storage.
        var name = filename
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\\\", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if name.isEmpty { name = "download" }
        if name.hasPrefix(".") { name = "download\(name)" }

        // Drop control characters.
        name = String(name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
        if name.isEmpty { name = "download" }

        // Reasonable length cap.
        if name.count > 180 {
            name = String(name.prefix(180))
        }
        return name
    }

    // MARK: - Storage maintenance

    public func pruneStorage(now: Date = Date()) -> DownloadStorageMetrics {
        prunePersistentDownloadsIfNeeded(now: now)
        pruneTemporaryDownloadsIfNeeded(now: now)
        return storageMetrics(now: now)
    }

    public func storageMetrics(now: Date = Date()) -> DownloadStorageMetrics {
        _ = now

        let persistentDir = downloadsDirectoryURL(profile: .regular)
        let tempDir = downloadsDirectoryURL(profile: .private)
        let persistent = directoryMetrics(dir: persistentDir, includeHidden: false)
        let tempVisible = directoryMetrics(dir: tempDir, includeHidden: false)
        let tempResume = directoryMetrics(dir: resumeDataDirectoryURL(profile: .private), includeHidden: true)

        return DownloadStorageMetrics(
            persistentFileCount: persistent.count,
            persistentTotalBytes: persistent.totalBytes,
            temporaryFileCount: tempVisible.count + tempResume.count,
            temporaryTotalBytes: tempVisible.totalBytes + tempResume.totalBytes
        )
    }

    private func prunePersistentDownloadsIfNeeded(now: Date) {
        let maxCount = max(0, options.persistentMaxFileCount)
        let maxBytes = options.persistentMaxTotalBytes

        if maxCount == 0 && maxBytes == nil { return }

        let dir = downloadsDirectoryURL(profile: .regular)
        let entries = listDirectoryEntries(dir: dir, includeHidden: false)
            .sorted(by: { $0.modifiedAt < $1.modifiedAt })

        var remaining = entries
        var bytes = remaining.reduce(Int64(0), { $0 + $1.sizeBytes })

        var deletions: [URL] = []

        if maxCount > 0, remaining.count > maxCount {
            let overflow = remaining.count - maxCount
            let victims = remaining.prefix(overflow)
            deletions.append(contentsOf: victims.map(\.url))
            bytes -= victims.reduce(Int64(0), { $0 + $1.sizeBytes })
            remaining.removeFirst(overflow)
        }

        if let maxBytes {
            while bytes > maxBytes, let victim = remaining.first {
                deletions.append(victim.url)
                bytes -= victim.sizeBytes
                remaining.removeFirst()
            }
        }

        for url in deletions {
            try? fileManager.removeItem(at: url)
        }

        _ = now
    }

    private func pruneTemporaryDownloadsIfNeeded(now: Date) {
        let cutoff = now.addingTimeInterval(-options.temporaryMaxAge)

        let tempDir = downloadsDirectoryURL(profile: .private)
        let tempEntries = listDirectoryEntries(dir: tempDir, includeHidden: false)
        for e in tempEntries where e.modifiedAt < cutoff {
            try? fileManager.removeItem(at: e.url)
        }

        let resumeDir = resumeDataDirectoryURL(profile: .private)
        let resumeEntries = listDirectoryEntries(dir: resumeDir, includeHidden: true)
        for e in resumeEntries where e.modifiedAt < cutoff {
            try? fileManager.removeItem(at: e.url)
        }
    }

    private struct DirectoryEntry {
        let url: URL
        let modifiedAt: Date
        let sizeBytes: Int64
    }

    private struct DirectoryMetrics {
        let count: Int
        let totalBytes: Int64
    }

    private func directoryMetrics(dir: URL, includeHidden: Bool) -> DirectoryMetrics {
        let entries = listDirectoryEntries(dir: dir, includeHidden: includeHidden)
        let total = entries.reduce(Int64(0), { $0 + $1.sizeBytes })
        return DirectoryMetrics(count: entries.count, totalBytes: total)
    }

    private func listDirectoryEntries(dir: URL, includeHidden: Bool) -> [DirectoryEntry] {
        let options: FileManager.DirectoryEnumerationOptions = includeHidden ? [] : [.skipsHiddenFiles]
        guard let urls = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
            options: options
        ) else {
            return []
        }

        return urls.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey])
            if values?.isDirectory == true { return nil }
            let modifiedAt = values?.contentModificationDate ?? Date.distantPast
            let sizeBytes = Int64(values?.fileSize ?? 0)
            return DirectoryEntry(url: url, modifiedAt: modifiedAt, sizeBytes: sizeBytes)
        }
    }
}
