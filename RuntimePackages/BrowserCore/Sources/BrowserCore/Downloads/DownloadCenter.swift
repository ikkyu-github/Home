import Foundation
import SafariLikeContracts
import os

/// BrowserCore download coordinator.
///
/// Responsibilities:
/// - Own URLSession download tasks (background for regular, ephemeral for private).
/// - Persist and restore regular download state.
/// - Provide scene/profile filtered snapshots for UI adapters.
///
/// Layering: UI-free (no UIKit/SwiftUI/WebKit imports).
public actor DownloadCenter {
    public struct Options: Sendable {
        public var stateFilename: String
        public var backgroundSessionIdentifier: String
        public var progressThrottleInterval: TimeInterval

        public init(
            stateFilename: String = "downloads_state_v2.json",
            backgroundSessionIdentifier: String = "com.ikkyu.webOS.downloads.background",
            progressThrottleInterval: TimeInterval = 0.15
        ) {
            self.stateFilename = stateFilename
            self.backgroundSessionIdentifier = backgroundSessionIdentifier
            self.progressThrottleInterval = progressThrottleInterval
        }
    }

    private static let logger = Logger(subsystem: "BrowserCore", category: "DownloadCenter")

    private let options: Options
    private let fileIO: any DownloadFileIO

    private let persistence: JSONFileStoreActor

    // Regular: background-capable
    private lazy var regularSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: options.backgroundSessionIdentifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: delegateProxy, delegateQueue: nil)
    }()

    // Private: ephemeral; no persistence
    private lazy var privateSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: delegateProxy, delegateQueue: nil)
    }()

    private var recordsByID: [UUID: DownloadRecord] = [:]

    // task.taskDescription(UUID string) -> record id
    private func recordID(for task: URLSessionTask) -> UUID? {
        guard let s = task.taskDescription else { return nil }
        return UUID(uuidString: s)
    }

    // Throttle progress updates (avoid UI churn)
    private var lastProgressEmitAtByID: [UUID: Date] = [:]

    // Per-scene subscribers
    public typealias SnapshotHandler = @Sendable ([DownloadActivity]) -> Void
    private var observersByToken: [UUID: (sceneID: String, profile: DownloadProfile, handler: SnapshotHandler)] = [:]

    // Background URLSession bridging
    private var backgroundEventsCompletionHandler: (() -> Void)?

    // Delegate proxy (class) receives URLSession callbacks on arbitrary threads.
    private let delegateProxy: DelegateProxy

    public init(options: Options = .init(), fileIO: any DownloadFileIO, autoBootstrap: Bool = true) {
        self.options = options
        self.fileIO = fileIO
        self.persistence = JSONFileStoreActor()
        let ownerBox = WeakOwnerBox<DownloadCenter>()
        self.delegateProxy = DelegateProxy(forward: { event in
            guard let owner = ownerBox.value else { return }
            Task {
                await owner.handle(event: event)
            }
        })
        ownerBox.value = self

        if autoBootstrap {
            Task {
                await bootstrap()
            }
        }
    }

    // MARK: - Bootstrap

    public func bootstrap() async {
        let persisted: PersistedState = await persistence.load(filename: options.stateFilename, defaultValue: PersistedState(records: []))
        // Keep only regular records; private is never persisted.
        recordsByID = Dictionary(uniqueKeysWithValues: persisted.records.filter { $0.profile == .regular }.map { ($0.id, $0) })
        await reconcileWithExistingSessionTasks()

        if let maintainer = fileIO as? any DownloadStorageMaintaining {
            let metrics = maintainer.pruneStorage(now: Date())
            #if DEBUG
            Self.logger.debug("storage.prune persistentCount=\(metrics.persistentFileCount) persistentBytes=\(metrics.persistentTotalBytes) tempCount=\(metrics.temporaryFileCount) tempBytes=\(metrics.temporaryTotalBytes)")
            #endif
        }

        await emitAllSnapshots(reason: "bootstrap")
    }

    // MARK: - Public API

    public func observeActivities(sceneID: String, profile: DownloadProfile, handler: @escaping SnapshotHandler) -> UUID {
        let token = UUID()
        observersByToken[token] = (sceneID: sceneID, profile: profile, handler: handler)
        // Send initial snapshot.
        handler(activities(sceneID: sceneID, profile: profile))
        return token
    }

    public func removeObserver(_ token: UUID) {
        observersByToken.removeValue(forKey: token)
    }

    /// Returns the current UI-friendly activities snapshot for a scene/profile.
    ///
    /// This is useful for deterministic callers (e.g. unit tests) that don't need subscription semantics.
    public func currentActivities(sceneID: String, profile: DownloadProfile) -> [DownloadActivity] {
        activities(sceneID: sceneID, profile: profile)
    }

    public func listFiles() -> [SafariLikeContracts.DownloadFile] {
        fileIO.listFiles()
    }

    public func makeDestinationURL(for filename: String, profile: DownloadProfile) -> URL {
        fileIO.makeDestinationURL(for: filename, profile: profile)
    }

    public func startDownload(sceneID: String, profile: DownloadProfile, request: URLRequest, response: URLResponse?) {
        guard let url = request.url else { return }

        let filename = suggestedFilename(from: response, fallbackURL: url)
        let destinationURL = makeDestinationURL(for: filename, profile: profile)

        let id = UUID()
        let now = Date()
        let record = DownloadRecord(
            id: id,
            sceneID: sceneID,
            profile: profile,
            sourceURL: url,
            destinationURL: destinationURL,
            filename: filename,
            status: .queued,
            bytesWritten: 0,
            bytesExpected: nil,
            createdAt: now,
            updatedAt: now,
            resumeDataFilename: nil,
            errorMessage: nil
        )
        recordsByID[id] = record
        persistStateSoonIfAllowed(profile: profile)
        emitSnapshotsIfNeeded(sceneID: sceneID, profile: profile, reason: "start.queued")

        let task: URLSessionDownloadTask = session(for: profile).downloadTask(with: request)
        task.taskDescription = id.uuidString
        recordsByID[id]?.status = .downloading
        recordsByID[id]?.updatedAt = Date()
        recordsByID[id]?.errorMessage = nil
        persistStateSoonIfAllowed(profile: profile)
        emitSnapshotsIfNeeded(sceneID: sceneID, profile: profile, reason: "start.downloading")
        task.resume()
    }

    public func pauseDownload(id: UUID) {
        Task { await pauseDownloadInternal(id: id) }
    }

    private func pauseDownloadInternal(id: UUID) async {
        guard let record = recordsByID[id] else { return }
        guard let downloadTask = await sessionTask(for: id, profile: record.profile) as? URLSessionDownloadTask else {
            var updated = record
            updated.status = .paused
            updated.updatedAt = Date()
            updated.errorMessage = nil
            recordsByID[id] = updated
            persistStateSoonIfAllowed(profile: updated.profile)
            emitSnapshotsIfNeeded(sceneID: updated.sceneID, profile: updated.profile, reason: "pause.noTask")
            return
        }
        let resumeData = await Self.cancelProducingResumeData(downloadTask)
        var updated = record
        if let resumeData {
            updated.resumeDataFilename = writeResumeData(resumeData, for: id, profile: record.profile)
        }
        updated.status = .paused
        updated.updatedAt = Date()
        updated.errorMessage = nil
        recordsByID[id] = updated
        persistStateSoonIfAllowed(profile: updated.profile)
        emitSnapshotsIfNeeded(sceneID: updated.sceneID, profile: updated.profile, reason: "pause")
    }

    public func resumeDownload(id: UUID) {
        guard var record = recordsByID[id] else { return }
        record.errorMessage = nil

        if let name = record.resumeDataFilename {
            if let data = try? fileIO.readResumeData(named: name, profile: record.profile) {
                deleteResumeDataFile(named: name, profile: record.profile)
                record.resumeDataFilename = nil
                record.status = .downloading
                record.updatedAt = Date()
                record.errorMessage = nil
                recordsByID[id] = record
                persistStateSoonIfAllowed(profile: record.profile)
                emitSnapshotsIfNeeded(sceneID: record.sceneID, profile: record.profile, reason: "resume.resumeData")

                let task = session(for: record.profile).downloadTask(withResumeData: data)
                task.taskDescription = id.uuidString
                task.resume()
                return
            }
        }

        let request = URLRequest(url: record.sourceURL)
        record.status = .downloading
        record.updatedAt = Date()
        record.errorMessage = nil
        recordsByID[id] = record
        persistStateSoonIfAllowed(profile: record.profile)
        emitSnapshotsIfNeeded(sceneID: record.sceneID, profile: record.profile, reason: "resume.restart")

        let task = session(for: record.profile).downloadTask(with: request)
        task.taskDescription = id.uuidString
        task.resume()
    }

    public func cancelDownload(id: UUID) {
        guard var record = recordsByID[id] else { return }

        record.status = .canceled
        record.updatedAt = Date()
        if let name = record.resumeDataFilename {
            deleteResumeDataFile(named: name, profile: record.profile)
        }
        record.resumeDataFilename = nil
        record.errorMessage = nil
        recordsByID[id] = record
        persistStateSoonIfAllowed(profile: record.profile)
        emitSnapshotsIfNeeded(sceneID: record.sceneID, profile: record.profile, reason: "cancel")

        Task {
            let task = await self.sessionTask(for: id, profile: record.profile)
            task?.cancel()
        }
    }

    public func purgePrivateDownloads(sceneID: String) {
        // Best-effort purge of private-mode artifacts.
        let records = recordsByID.values.filter { $0.sceneID == sceneID && $0.profile == .private }
        for record in records {
            if let name = record.resumeDataFilename {
                deleteResumeDataFile(named: name, profile: .private)
            }
            // Destination URLs for private downloads should point at an ephemeral directory.
            // Remove the file on disk best-effort to avoid cross-launch leakage.
            try? FileManager.default.removeItem(at: record.destinationURL)

            recordsByID.removeValue(forKey: record.id)
            lastProgressEmitAtByID.removeValue(forKey: record.id)
        }
        emitSnapshotsIfNeeded(sceneID: sceneID, profile: .private, reason: "purgePrivate")
    }

    public func handleEventsForBackgroundURLSession(identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == options.backgroundSessionIdentifier else {
            completionHandler()
            return
        }
        backgroundEventsCompletionHandler = completionHandler
    }

    // MARK: - Internals

    private func session(for profile: DownloadProfile) -> URLSession {
        switch profile {
        case .regular: return regularSession
        case .private: return privateSession

        @unknown default:
            assertionFailure("Unhandled profile: \(profile)")
            return regularSession
        }
    }

    private func activities(sceneID: String, profile: DownloadProfile) -> [DownloadActivity] {
        recordsByID.values
            .filter { $0.sceneID == sceneID && $0.profile == profile }
            .filter { $0.status == .queued || $0.status == .downloading || $0.status == .paused || $0.status == .failed }
            .sorted(by: { $0.createdAt > $1.createdAt })
            .map { r in
                DownloadActivity(
                    id: r.id,
                    sceneID: r.sceneID,
                    profile: r.profile,
                    url: r.sourceURL,
                    filename: r.filename,
                    progress: r.progress,
                    status: r.status,
                    errorMessage: r.errorMessage
                )
            }
    }

    private func emitSnapshotsIfNeeded(sceneID: String, profile: DownloadProfile, reason: String) {
        // Notify only observers matching scene/profile.
        let snapshot = activities(sceneID: sceneID, profile: profile)
        for (_, obs) in observersByToken where obs.sceneID == sceneID && obs.profile == profile {
            obs.handler(snapshot)
        }
        _ = reason
    }

    private func emitAllSnapshots(reason: String) async {
        let observers = observersByToken
        for (_, obs) in observers {
            obs.handler(activities(sceneID: obs.sceneID, profile: obs.profile))
        }
        _ = reason
    }

    private struct PersistedState: Codable, Sendable {
        var records: [DownloadRecord]
    }

    private func persistStateSoonIfAllowed(profile: DownloadProfile) {
        guard profile == .regular else { return }
        let snapshot = Array(recordsByID.values.filter { $0.profile == .regular })
        Task {
            await persistence.save(filename: options.stateFilename, value: PersistedState(records: snapshot))
        }
    }

    private func reconcileWithExistingSessionTasks() async {
        // Only meaningful for regular background session.
        await withCheckedContinuation { continuation in
            regularSession.getAllTasks { [weak self] tasks in
                guard let self else {
                    continuation.resume()
                    return
                }
                Task { [tasks] in
                    await self.reconcileWithExistingSessionTasks(tasks)
                    continuation.resume()
                }
            }
        }
    }

    private func reconcileWithExistingSessionTasks(_ tasks: [URLSessionTask]) {
        for task in tasks {
            guard let id = recordID(for: task) else { continue }
            guard var record = recordsByID[id] else { continue }
            if record.status != .finished {
                record.status = .downloading
                record.updatedAt = Date()
                recordsByID[id] = record
            }
        }
        persistStateSoonIfAllowed(profile: .regular)
    }

    private func sessionTask(for id: UUID, profile: DownloadProfile) async -> URLSessionTask? {
        await withCheckedContinuation { continuation in
            session(for: profile).getAllTasks { tasks in
                let match = tasks.first(where: { $0.taskDescription == id.uuidString })
                continuation.resume(returning: match)
            }
        }
    }

    private enum DelegateEvent: Sendable {
        case didWriteData(id: UUID, bytesWritten: Int64, bytesExpected: Int64)
        case didFinish(id: UUID, tempURL: URL)
        case didComplete(id: UUID, error: Error?)
        case didFinishBackgroundEvents
    }

    private func handle(event: DelegateEvent) async {
        switch event {
        case let .didWriteData(id, bytesWritten, bytesExpected):
            guard var record = recordsByID[id] else { return }
            let now = Date()
            let lastEmit = lastProgressEmitAtByID[id] ?? .distantPast
            if now.timeIntervalSince(lastEmit) < options.progressThrottleInterval {
                // Still update bytes for persistence accuracy, but don't emit snapshots.
                record.bytesWritten = bytesWritten
                record.bytesExpected = bytesExpected
                record.updatedAt = now
                recordsByID[id] = record
                persistStateSoonIfAllowed(profile: record.profile)
                return
            }
            lastProgressEmitAtByID[id] = now

            record.bytesWritten = bytesWritten
            record.bytesExpected = bytesExpected
            record.updatedAt = now
            record.status = .downloading
            recordsByID[id] = record
            persistStateSoonIfAllowed(profile: record.profile)
            emitSnapshotsIfNeeded(sceneID: record.sceneID, profile: record.profile, reason: "progress")

        case let .didFinish(id, tempURL):
            guard var record = recordsByID[id] else { return }
            do {
                try fileIO.commitDownloadedTempFile(from: tempURL, to: record.destinationURL)
                record.status = .finished
                record.updatedAt = Date()
                record.errorMessage = nil
                recordsByID[id] = record
            } catch {
                record.status = .failed
                record.updatedAt = Date()
                record.errorMessage = error.localizedDescription
                recordsByID[id] = record
            }
            persistStateSoonIfAllowed(profile: record.profile)
            emitSnapshotsIfNeeded(sceneID: record.sceneID, profile: record.profile, reason: "finish")

        case let .didComplete(id, error):
            guard var record = recordsByID[id] else { return }
            if record.status == .canceled {
                // Keep canceled.
            } else if let error {
                record.status = .failed
                record.errorMessage = error.localizedDescription
            }
            record.updatedAt = Date()
            recordsByID[id] = record
            persistStateSoonIfAllowed(profile: record.profile)
            emitSnapshotsIfNeeded(sceneID: record.sceneID, profile: record.profile, reason: "complete")

        case .didFinishBackgroundEvents:
            backgroundEventsCompletionHandler?()
            backgroundEventsCompletionHandler = nil
        }
    }

    private func writeResumeData(_ data: Data, for id: UUID, profile: DownloadProfile) -> String {
        do {
            return try fileIO.writeResumeData(data, for: id, profile: profile)
        } catch {
            return "\(id.uuidString).resume"
        }
    }

    private func deleteResumeDataFile(named name: String, profile: DownloadProfile) {
        try? fileIO.deleteResumeData(named: name, profile: profile)
    }

    private static func cancelProducingResumeData(_ task: URLSessionDownloadTask) async -> Data? {
        await withCheckedContinuation { continuation in
            task.cancel(byProducingResumeData: { resumeData in
                continuation.resume(returning: resumeData)
            })
        }
    }

    private func suggestedFilename(from response: URLResponse?, fallbackURL: URL) -> String {
        if let http = response as? HTTPURLResponse,
           let cd = http.value(forHTTPHeaderField: "Content-Disposition")?.lowercased() {
            if let r = cd.range(of: "filename=") {
                let tail = cd[r.upperBound...]
                let trimmed = tail.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("\"") {
                    if let end = trimmed.dropFirst().firstIndex(of: "\"") {
                        let name = String(trimmed.dropFirst().prefix(upTo: end))
                        if !name.isEmpty { return name }
                    }
                } else {
                    let name = trimmed.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init)
                    if let name, !name.isEmpty { return name }
                }
            }
        }
        let last = fallbackURL.lastPathComponent
        if !last.isEmpty { return last }
        return "download"
    }

    // MARK: - Delegate proxy

    private final class DelegateProxy: NSObject, URLSessionDownloadDelegate, URLSessionDelegate {
        private let forward: @Sendable (DelegateEvent) -> Void

        init(forward: @escaping @Sendable (DelegateEvent) -> Void) {
            self.forward = forward
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            guard let s = downloadTask.taskDescription, let id = UUID(uuidString: s) else { return }
            forward(.didWriteData(id: id, bytesWritten: totalBytesWritten, bytesExpected: totalBytesExpectedToWrite))
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            guard let s = downloadTask.taskDescription, let id = UUID(uuidString: s) else { return }
            forward(.didFinish(id: id, tempURL: location))
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            guard let s = task.taskDescription, let id = UUID(uuidString: s) else { return }
            forward(.didComplete(id: id, error: error))
        }

        func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
            forward(.didFinishBackgroundEvents)
        }
    }

    private final class WeakOwnerBox<T: AnyObject>: @unchecked Sendable {
        weak var value: T?
        init() {}
    }
}
