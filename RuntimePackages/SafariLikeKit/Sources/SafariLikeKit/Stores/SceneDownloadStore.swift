import Foundation
import Combine
import SafariLikeCoreKit
import SafariLikeContracts

/// SafariLikeKit adapter that exposes BrowserCore `DownloadCenter` to the UI.
///
/// - Keeps BrowserCore UI-free.
/// - Keeps per-scene presentation isolation by filtering snapshots by `sceneID`.
@MainActor
public final class DownloadCenterAdapter: ObservableObject, DownloadProviding {
    private let center: DownloadCenter
    private let fileIO: any DownloadFileIO
    private let sceneID: String
    private var activeProfile: BrowsingProfile = .regular

    private var regularObserverToken: UUID?
    private var privateObserverToken: UUID?

    private var regularActivities: [DownloadActivity] = []
    private var privateActivities: [DownloadActivity] = []

    @Published public private(set) var files: [DownloadFile] = []
    @Published public private(set) var activeDownloads: [DownloadActivity] = []
    @Published public var lastErrorMessage: String? = nil

    public init(
        center: DownloadCenter,
        fileIO: any DownloadFileIO,
        sceneID: String,
        initialProfile: BrowsingProfile = .regular
    ) {
        self.center = center
        self.fileIO = fileIO
        self.sceneID = sceneID
        self.activeProfile = initialProfile

        // Initial file list.
        refresh()

        Task { [center] in
            let token = await center.observeActivities(sceneID: sceneID, profile: .regular) { [weak self] activities in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.regularActivities = activities
                    self.recomputeActiveDownloads()
                }
            }
            await MainActor.run {
                self.regularObserverToken = token
            }
        }

        Task { [center] in
            let token = await center.observeActivities(sceneID: sceneID, profile: .private) { [weak self] activities in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.privateActivities = activities
                    self.recomputeActiveDownloads()
                }
            }
            await MainActor.run {
                self.privateObserverToken = token
            }
        }

        recomputeActiveDownloads()
    }

    deinit {
        if let token = regularObserverToken {
            Task { [center] in
                await center.removeObserver(token)
            }
        }
        if let token = privateObserverToken {
            Task { [center] in
                await center.removeObserver(token)
            }
        }
    }

    public func refresh() {
        Task {
            let list = await center.listFiles()
            await MainActor.run {
                self.files = list
            }
        }
    }

    public func failActiveDownload(error: Error) {
        lastErrorMessage = error.localizedDescription
    }

    public func makeDestinationURL(for filename: String) -> URL {
        let p: DownloadProfile = (activeProfile == .private) ? .private : .regular
        return fileIO.makeDestinationURL(for: filename, profile: p)
    }

    public func startDownload(sceneID: String, profile: BrowsingProfile, request: URLRequest, response: URLResponse?) {
        let p: DownloadProfile = (profile == .private) ? .private : .regular
        Task { [center] in
            await center.startDownload(sceneID: sceneID, profile: p, request: request, response: response)
        }
    }

    public func pauseDownload(id: UUID) {
        Task { [center] in
            await center.pauseDownload(id: id)
        }
    }

    public func resumeDownload(id: UUID) {
        Task { [center] in
            await center.resumeDownload(id: id)
        }
    }

    public func cancelDownload(id: UUID) {
        Task { [center] in
            await center.cancelDownload(id: id)
        }
    }

    /// Scene shutdown hook.
    public func purgePrivateDownloadsForScene() {
        Task { [center, sceneID] in
            await center.purgePrivateDownloads(sceneID: sceneID)
        }
    }

    public func setActiveProfile(_ profile: BrowsingProfile) {
        activeProfile = profile
        recomputeActiveDownloads()
    }

    private func recomputeActiveDownloads() {
        switch activeProfile {
        case .regular:
            activeDownloads = regularActivities
        case .private:
            activeDownloads = privateActivities

        @unknown default:
            assertionFailure("Unhandled BrowsingProfile: \(activeProfile)")
            activeDownloads = regularActivities
        }
    }
}

/// Backwards-compatible name: this type was previously called `SceneDownloadStore`.
public typealias SceneDownloadStore = DownloadCenterAdapter
