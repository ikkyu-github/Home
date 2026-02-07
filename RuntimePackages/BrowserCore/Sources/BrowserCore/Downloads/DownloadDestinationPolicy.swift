import Foundation

/// Synchronous destination policy for downloads.
///
/// This is intentionally not an actor so it can be used from WebKit delegate
/// decision handlers that require synchronous answers.
public struct DownloadDestinationPolicy: Sendable {
    public struct Options: Sendable {
        public var rootDirectory: URL?
        public var downloadsFolderName: String

        public init(rootDirectory: URL? = nil, downloadsFolderName: String = "Downloads") {
            self.rootDirectory = rootDirectory
            self.downloadsFolderName = downloadsFolderName
        }
    }

    private let options: Options

    public init(options: Options = .init()) {
        self.options = options
    }

    public func downloadsDirectoryURL(fileManager: FileManager = .default) -> URL {
        if let root = options.rootDirectory {
            let dir = root.appendingPathComponent(options.downloadsFolderName, isDirectory: true)
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            }
            return dir
        }

        if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let dir = docs.appendingPathComponent(options.downloadsFolderName, isDirectory: true)
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            }
            return dir
        }

        return fileManager.temporaryDirectory
    }

    public func makeDestinationURL(for filename: String, fileManager: FileManager = .default) -> URL {
        let base = downloadsDirectoryURL(fileManager: fileManager)
        let candidate = base.appendingPathComponent(filename)
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

    public func resumeDataDirectoryURL(fileManager: FileManager = .default) -> URL {
        let base = downloadsDirectoryURL(fileManager: fileManager).appendingPathComponent(".resume-data", isDirectory: true)
        if !fileManager.fileExists(atPath: base.path) {
            try? fileManager.createDirectory(at: base, withIntermediateDirectories: true, attributes: nil)
        }
        return base
    }
}
