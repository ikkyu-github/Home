import Foundation
import SafariLikeCoreKit
import SafariLikeContracts
// MARK: - Architecture: Download Management Protocol
/// Platform-independent interface for download file management.
///
/// **Purpose:**
/// Provides a clean separation between Core download state management
/// and UI layer file system operations (FileManager, document directories).
///
/// **Separation:**
/// - Protocol focuses on: file listing, refresh, error reporting
/// - No UIKit dependencies
/// - Suitable for Core layer and cross-platform use
///
/// **Thread Safety:**
/// Implementations should be @MainActor isolated for thread safety.
/// Download management abstraction.
@MainActor
public protocol DownloadProviding: AnyObject {
    /// Currently available downloaded files, sorted by recency.
    /// Published for reactive updates.
    var files: [DownloadFile] { get }

    /// In-progress activities (queued/downloading/paused/failed).
    ///
    /// Implementations that do not support task management may return an empty list.
    var activeDownloads: [DownloadActivity] { get }

    /// Inform the store about the currently active browsing profile for this scene.
    ///
    /// Stores that keep per-profile activity streams can use this to avoid leaking
    /// private downloads into regular UI (and vice versa).
    func setActiveProfile(_ profile: BrowsingProfile)
    /// Most recent download error message, if any.
    /// Can be set to nil to clear the error state.
    var lastErrorMessage: String? { get set }
    /// Refreshes the file list from persistent storage.
    /// Called when the downloads view appears or is focused.
    ///
    /// Threading: Call on the main actor.
    func refresh()
    /// Records a download failure for UI notification.
    ///
    /// - Parameter error: The error that occurred during download
    ///
    /// Threading: Call on the main actor.
    func failActiveDownload(error: Error)
    /// Computes a destination URL for a new download with the given filename.
    /// Implementations may map this into an appropriate downloads directory.
    func makeDestinationURL(for filename: String) -> URL
    /// Starts a new download.
    ///
    /// Intended to be called from WebKit interception points (e.g. WKNavigationDelegate)
    /// when a navigation should be treated as a file download.
    ///
    /// Threading: Call on the main actor.
    func startDownload(sceneID: String, profile: BrowsingProfile, request: URLRequest, response: URLResponse?)
    /// Requests that an in-flight download be paused.
    ///
    /// Implementations should capture resume data when available.
    /// Threading: Call on the main actor.
    func pauseDownload(id: UUID)
    /// Requests that a previously-paused download be resumed.
    ///
    /// Implementations may resume from stored resume data or restart.
    /// Threading: Call on the main actor.
    func resumeDownload(id: UUID)
    /// Cancels an in-flight or queued download.
    ///
    /// Threading: Call on the main actor.
    func cancelDownload(id: UUID)

    /// Purge any private-mode in-memory download state for this scene.
    ///
    /// Regular-mode on-disk downloads are not affected.
    func purgePrivateDownloadsForScene()
}

public extension DownloadProviding {
    func setActiveProfile(_ profile: BrowsingProfile) {
        _ = profile
    }

    func purgePrivateDownloadsForScene() {
    }
}
