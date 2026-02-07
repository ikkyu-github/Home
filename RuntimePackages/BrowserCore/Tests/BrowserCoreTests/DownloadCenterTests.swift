import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class DownloadCenterTests: XCTestCase {
    private struct PersistedState: Codable, Sendable {
        var records: [DownloadRecord]
    }

    private final class TestDownloadFileIO: DownloadFileIO, @unchecked Sendable {
        private let downloadsDirectory: URL
        private let resumeDirectory: URL
        private let tempDownloadsDirectory: URL
        private let tempResumeDirectory: URL

        init(root: URL) {
            self.downloadsDirectory = root.appendingPathComponent("downloads", isDirectory: true)
            self.resumeDirectory = root.appendingPathComponent("resume", isDirectory: true)
            self.tempDownloadsDirectory = root.appendingPathComponent("tmp-downloads", isDirectory: true)
            self.tempResumeDirectory = root.appendingPathComponent("tmp-resume", isDirectory: true)
        }

        func makeDestinationURL(for filename: String, profile: DownloadProfile) -> URL {
            let base: URL = (profile == .private) ? tempDownloadsDirectory : downloadsDirectory
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

            let candidate = base.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            let stem = candidate.deletingPathExtension().lastPathComponent
            let ext = candidate.pathExtension
            for i in 2...999 {
                let name = ext.isEmpty ? "\(stem)-\(i)" : "\(stem)-\(i).\(ext)"
                let url = base.appendingPathComponent(name)
                if !FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
            return base.appendingPathComponent("\(UUID().uuidString)-\(filename)")
        }

        func listFiles() -> [DownloadFile] {
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: downloadsDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            return urls.compactMap { url in
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let modifiedAt = values?.contentModificationDate ?? Date.distantPast
                let sizeBytes = Int64(values?.fileSize ?? 0)
                return DownloadFile(url: url, name: url.lastPathComponent, modifiedAt: modifiedAt, sizeBytes: sizeBytes)
            }
        }

        func writeResumeData(_ data: Data, for id: UUID, profile: DownloadProfile) throws -> String {
            let base: URL = (profile == .private) ? tempResumeDirectory : resumeDirectory
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            let name = "\(id.uuidString).resume"
            let url = base.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            return name
        }

        func readResumeData(named name: String, profile: DownloadProfile) throws -> Data {
            let base: URL = (profile == .private) ? tempResumeDirectory : resumeDirectory
            return try Data(contentsOf: base.appendingPathComponent(name))
        }

        func deleteResumeData(named name: String, profile: DownloadProfile) throws {
            let base: URL = (profile == .private) ? tempResumeDirectory : resumeDirectory
            let url = base.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }

        func commitDownloadedTempFile(from tempURL: URL, to destinationURL: URL) throws {
            try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        }
    }

    private func documentsURL() throws -> URL {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return url
    }

    func test_bootstrapFiltersPrivateRecordsFromPersistence() async throws {
        let stateFilename = "downloads_state_test_\(UUID().uuidString).json"
        let docs = try documentsURL()
        defer { try? FileManager.default.removeItem(at: docs.appendingPathComponent(stateFilename)) }

        let now = Date()
        let recordRegular = DownloadRecord(
            id: UUID(),
            sceneID: "sceneA",
            profile: .regular,
            sourceURL: URL(string: "https://example.com/a")!,
            destinationURL: URL(fileURLWithPath: "/tmp/a"),
            filename: "a",
            status: .paused,
            bytesWritten: 1,
            bytesExpected: 10,
            createdAt: now,
            updatedAt: now,
            resumeDataFilename: nil,
            errorMessage: nil
        )
        let recordPrivate = DownloadRecord(
            id: UUID(),
            sceneID: "sceneA",
            profile: .private,
            sourceURL: URL(string: "https://example.com/b")!,
            destinationURL: URL(fileURLWithPath: "/tmp/b"),
            filename: "b",
            status: .paused,
            bytesWritten: 2,
            bytesExpected: 10,
            createdAt: now,
            updatedAt: now,
            resumeDataFilename: nil,
            errorMessage: nil
        )

        await JSONFileStoreActor().save(filename: stateFilename, value: PersistedState(records: [recordRegular, recordPrivate]))

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("DownloadCenterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let center = DownloadCenter(
            options: .init(
                stateFilename: stateFilename,
                backgroundSessionIdentifier: "com.ikkyu.webOS.downloads.background.test.\(UUID().uuidString)",
                progressThrottleInterval: 0
            ),
            fileIO: TestDownloadFileIO(root: tmp),
            autoBootstrap: false
        )

        await center.bootstrap()

        let regularSnapshot = await center.currentActivities(sceneID: "sceneA", profile: .regular)
        XCTAssertEqual(regularSnapshot.map(\.id), [recordRegular.id])

        let privateSnapshot = await center.currentActivities(sceneID: "sceneA", profile: .private)
        XCTAssertTrue(privateSnapshot.isEmpty)
    }

    func test_privateDownloadsAreNotWrittenToPersistedState() async throws {
        let stateFilename = "downloads_state_test_\(UUID().uuidString).json"
        let docs = try documentsURL()
        defer { try? FileManager.default.removeItem(at: docs.appendingPathComponent(stateFilename)) }

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("DownloadCenterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let center = DownloadCenter(
            options: .init(
                stateFilename: stateFilename,
                backgroundSessionIdentifier: "com.ikkyu.webOS.downloads.background.test.\(UUID().uuidString)",
                progressThrottleInterval: 0
            ),
            fileIO: TestDownloadFileIO(root: tmp),
            autoBootstrap: false
        )

        await center.bootstrap()

        let sourceFile = tmp.appendingPathComponent("source.dat")
        try Data("hello".utf8).write(to: sourceFile)

        await center.startDownload(
            sceneID: "scenePrivate",
            profile: .private,
            request: URLRequest(url: sourceFile),
            response: nil
        )

        try await Task.sleep(nanoseconds: 200_000_000)

        let persisted = await JSONFileStoreActor().load(filename: stateFilename, defaultValue: PersistedState(records: []))
        XCTAssertTrue(persisted.records.allSatisfy { $0.profile != .private })
    }

    func test_regularDownloadsAreWrittenToPersistedState() async throws {
        let stateFilename = "downloads_state_test_\(UUID().uuidString).json"
        let docs = try documentsURL()
        defer { try? FileManager.default.removeItem(at: docs.appendingPathComponent(stateFilename)) }

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("DownloadCenterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let center = DownloadCenter(
            options: .init(
                stateFilename: stateFilename,
                backgroundSessionIdentifier: "com.ikkyu.webOS.downloads.background.test.\(UUID().uuidString)",
                progressThrottleInterval: 0
            ),
            fileIO: TestDownloadFileIO(root: tmp),
            autoBootstrap: false
        )

        await center.bootstrap()

        let sourceFile = tmp.appendingPathComponent("source-regular.dat")
        try Data("hello".utf8).write(to: sourceFile)

        await center.startDownload(
            sceneID: "sceneRegular",
            profile: .regular,
            request: URLRequest(url: sourceFile),
            response: nil
        )

        // Allow async persistence task to run.
        try await Task.sleep(nanoseconds: 400_000_000)

        let persisted = await JSONFileStoreActor().load(filename: stateFilename, defaultValue: PersistedState(records: []))
        XCTAssertTrue(persisted.records.contains(where: { $0.sceneID == "sceneRegular" && $0.profile == .regular }))
        XCTAssertFalse(persisted.records.contains(where: { $0.profile == .private }))
    }
}
