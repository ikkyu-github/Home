import Foundation
import os

/// An actor for safe async JSON file I/O off the MainActor.
public actor JSONFileStoreActor {
    public typealias ErrorHandler = @Sendable (Error, String) -> Void

    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "SafariLikeContracts", category: "JSONFileStore")
    public var onError: ErrorHandler?

    public init(onError: ErrorHandler? = nil) {
        self.onError = onError
    }

    private func handleError(_ error: Error, filename: String, operation: String) {
        #if DEBUG
        logger.error("JSONFileStoreActor \(operation, privacy: .public) failed for '\(filename, privacy: .public)': \(String(describing: error), privacy: .public)")
        #endif
        onError?(error, filename)
    }

    private func documentsURL() throws -> URL {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return url
    }

    public func load<T: Decodable>(filename: String, defaultValue: T) async -> T {
        do {
            let url = try documentsURL().appendingPathComponent(filename)
            guard fileManager.fileExists(atPath: url.path) else {
                return defaultValue
            }
            let data = try Data(contentsOf: url)
            let value = try JSONDecoder().decode(T.self, from: data)
            return value
        } catch {
            handleError(error, filename: filename, operation: "load")
            return defaultValue
        }
    }

    public func save<T: Encodable>(filename: String, value: T) async {
        do {
            let url = try documentsURL().appendingPathComponent(filename)
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            handleError(error, filename: filename, operation: "save")
        }
    }
}
