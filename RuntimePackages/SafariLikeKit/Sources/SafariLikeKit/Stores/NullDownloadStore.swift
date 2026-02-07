import Foundation
import SafariLikeContracts
import SafariLikeCoreKit

/// A no-op downloads implementation.
///
/// Used as a safe default when the composition root does not inject a real
/// `DownloadProviding` implementation.
@MainActor
public final class NullDownloadStore: DownloadProviding {
    public private(set) var files: [DownloadFile] = []
    public private(set) var activeDownloads: [DownloadActivity] = []
    public var lastErrorMessage: String? = nil

    public init() {}

    public func refresh() {
        files = []
    }

    public func failActiveDownload(error: Error) {
        lastErrorMessage = error.localizedDescription
    }

    public func makeDestinationURL(for filename: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    public func startDownload(sceneID: String, profile: BrowsingProfile, request: URLRequest, response: URLResponse?) {
        _ = sceneID
        _ = profile
        _ = request
        _ = response
        lastErrorMessage = "Downloads are not configured. Inject DownloadCenterAdapter from the composition root."
    }

    public func pauseDownload(id: UUID) {
        _ = id
    }

    public func resumeDownload(id: UUID) {
        _ = id
    }

    public func cancelDownload(id: UUID) {
        _ = id
    }

    public func purgePrivateDownloadsForScene() {
    }
}
