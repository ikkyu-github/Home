import Foundation
import SafariLikeContracts
import os

/// Persists session state for a single scene/window using a directory bucket.
///
/// On-disk layout (under Application Support):
/// - `sessions/<scene>/tabs.json`
/// - `sessions/<scene>/groups.json`
/// - `sessions/<scene>/nav_state.json`
/// - `sessions/<scene>/recently_closed.json`
/// - `sessions/<scene>/continue_browsing.json`
/// - `sessions/<scene>/meta.json`
///
/// This store is intentionally file-granular so we can evolve individual payloads
/// without invalidating the whole window snapshot.
public actor SceneSessionStore {
    private static let logger = Logger(subsystem: "BrowserCore", category: "SceneSessionStore")

    private static let currentBucketSchemaVersion: Int = 1

    private enum Budgets {
        static let maxTabsToPersist: Int = 100
        static let maxRecentlyClosedToPersist: Int = 50
        static let maxSceneBucketsToKeep: Int = 12
    }

    public struct Options: Sendable {
        public var rootDirectory: URL?
        public var rootFolderName: String

        public init(rootDirectory: URL? = nil, rootFolderName: String = "sessions") {
            self.rootDirectory = rootDirectory
            self.rootFolderName = rootFolderName
        }
    }

    private let fileManager: FileManager
    private let options: Options

    public init(options: Options = .init(), fileManager: FileManager = .default) {
        self.options = options
        self.fileManager = fileManager
    }

    // MARK: - Public API

    public func loadWindowSessionState(sceneID: String, legacyFilename: String? = nil) async -> WindowSessionState {
        do {
            let bucketURL = try bucketDirectoryURL(sceneID: sceneID)
            if fileManager.fileExists(atPath: bucketURL.path) {
                let snapshot = try loadFromBucket(bucketURL: bucketURL)
                return snapshot
            }

            // Best-effort migration: move legacy per-scene buckets from Documents -> Application Support.
            if options.rootDirectory == nil,
               let legacyBucketURL = try legacyBucketDirectoryURLIfPresent(sceneID: sceneID),
               fileManager.fileExists(atPath: legacyBucketURL.path) {
                let snapshot = try loadFromBucket(bucketURL: legacyBucketURL)
                do {
                    try ensureDirectoryExists(bucketURL)
                    try saveToBucket(bucketURL: bucketURL, snapshot: snapshot)
                    // Best-effort cleanup of legacy bucket to avoid duplicates.
                    try? fileManager.removeItem(at: legacyBucketURL)
                } catch {
                    Self.logger.error("Legacy bucket migration failed. sceneID=\(sceneID, privacy: .public) error=\(String(describing: error), privacy: .public)")
                }
                return snapshot
            }

            if let legacyFilename,
               let legacy = try loadLegacyWindowSessionStateIfPresent(filename: legacyFilename) {
                // Best-effort migration into the new bucket format.
                do {
                    try ensureDirectoryExists(bucketURL)
                    try saveToBucket(bucketURL: bucketURL, snapshot: legacy)
                } catch {
                    // Migration failure should not prevent app from launching.
                    Self.logger.error("Legacy migration failed. sceneID=\(sceneID, privacy: .public) error=\(String(describing: error), privacy: .public)")
                }
                return legacy
            }
        } catch {
            Self.logger.error("Load failed. sceneID=\(sceneID, privacy: .public) error=\(String(describing: error), privacy: .public)")
        }

        // Default: single placeholder tab.
        return WindowSessionState(tabs: [BrowserTab()], selectedTabID: nil, tabGroups: [], selectedTabGroupID: nil)
    }

    public func saveWindowSessionState(sceneID: String, snapshot: WindowSessionState) async {
        do {
            let bucketURL = try bucketDirectoryURL(sceneID: sceneID)
            try ensureDirectoryExists(bucketURL)
            let budgetedSnapshot = applyPersistenceBudgets(snapshot)
            try saveToBucket(bucketURL: bucketURL, snapshot: budgetedSnapshot)

            // Deterministic cleanup: keep a bounded number of per-scene buckets.
            try? pruneOldBucketsIfNeeded(keepingMostRecent: Budgets.maxSceneBucketsToKeep)
        } catch {
            Self.logger.error("Save failed. sceneID=\(sceneID, privacy: .public) error=\(String(describing: error), privacy: .public)")
        }
    }

    public func loadContinueBrowsingSummary(sceneID: String) async -> SceneSessionSummary? {
        do {
            let url = try bucketDirectoryURL(sceneID: sceneID).appendingPathComponent(Filenames.continueBrowsing)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SceneSessionSummary.self, from: data)
        } catch {
            return nil
        }
    }

    public func saveContinueBrowsingSummary(sceneID: String, summary: SceneSessionSummary?) async {
        do {
            let bucketURL = try bucketDirectoryURL(sceneID: sceneID)
            try ensureDirectoryExists(bucketURL)
            let url = bucketURL.appendingPathComponent(Filenames.continueBrowsing)
            if let summary {
                let data = try JSONEncoder().encode(summary)
                try data.write(to: url, options: .atomic)
            } else {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
            }
        } catch {
            // Best-effort; ignore.
        }
    }

    public func purge(sceneID: String) async {
        do {
            let bucketURL = try bucketDirectoryURL(sceneID: sceneID)
            if fileManager.fileExists(atPath: bucketURL.path) {
                try fileManager.removeItem(at: bucketURL)
            }
        } catch {
            // Best-effort; ignore.
        }
    }

    public func listSceneIDs() async -> [String] {
        do {
            let root = try rootURL()
            guard fileManager.fileExists(atPath: root.path) else { return [] }
            let children = try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            return children.compactMap { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true ? url.lastPathComponent : nil
            }.sorted()
        } catch {
            return []
        }
    }

    // MARK: - Internals

    private enum Filenames {
        static let tabs = "tabs.json"
        static let groups = "groups.json"
        static let nav = "nav_state.json"
        static let recentlyClosed = "recently_closed.json"
        static let continueBrowsing = "continue_browsing.json"
        static let meta = "meta.json"
    }

    private struct MetaFile: Codable, Sendable, Equatable {
        var schemaVersion: Int
        var lastSavedAt: Date
    }

    private struct TabsFile: Codable, Sendable, Equatable {
        var tabs: [BrowserTab]
        var selectedTabID: UUID?
        var splitView: WindowSessionState.SplitViewState
        var ui: WindowSessionState.UIState
    }

    private struct GroupsFile: Codable, Sendable, Equatable {
        var tabGroups: [BrowserTabGroup]
        var selectedTabGroupID: UUID?
    }

    private func rootURL() throws -> URL {
        if let root = options.rootDirectory {
            return root.appendingPathComponent(options.rootFolderName, isDirectory: true)
        }
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return appSupport.appendingPathComponent(options.rootFolderName, isDirectory: true)
    }

    private func legacyDocumentsRootURL() throws -> URL {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return docs.appendingPathComponent(options.rootFolderName, isDirectory: true)
    }

    private func legacyBucketDirectoryURLIfPresent(sceneID: String) throws -> URL? {
        let root = try legacyDocumentsRootURL()
        return root.appendingPathComponent(Self.safeDirectoryName(for: sceneID), isDirectory: true)
    }

    private func bucketDirectoryURL(sceneID: String) throws -> URL {
        let root = try rootURL()
        return root.appendingPathComponent(Self.safeDirectoryName(for: sceneID), isDirectory: true)
    }

    private func ensureDirectoryExists(_ url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)

        // Best-effort: exclude session persistence from backups.
        // This data can be large and is safe to rebuild.
        if options.rootDirectory == nil {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableURL = url
            try? mutableURL.setResourceValues(values)
        }
    }

    private func loadFromBucket(bucketURL: URL) throws -> WindowSessionState {
        let tabsURL = bucketURL.appendingPathComponent(Filenames.tabs)
        let groupsURL = bucketURL.appendingPathComponent(Filenames.groups)
        let navURL = bucketURL.appendingPathComponent(Filenames.nav)
        let closedURL = bucketURL.appendingPathComponent(Filenames.recentlyClosed)
        let metaURL = bucketURL.appendingPathComponent(Filenames.meta)

        let decoder = JSONDecoder()

        if let meta: MetaFile = try loadIfPresent(url: metaURL, decoder: decoder) {
            if meta.schemaVersion > Self.currentBucketSchemaVersion {
                throw CocoaError(.fileReadCorruptFile)
            }
        }

        let tabsFile: TabsFile = try loadIfPresent(url: tabsURL, decoder: decoder) ?? TabsFile(
            tabs: [BrowserTab()],
            selectedTabID: nil,
            splitView: .init(),
            ui: .init()
        )
        let groupsFile: GroupsFile = try loadIfPresent(url: groupsURL, decoder: decoder) ?? GroupsFile(tabGroups: [], selectedTabGroupID: nil)
        let nav: [UUID: TabNavigationState] = try loadIfPresent(url: navURL, decoder: decoder) ?? [:]
        let recentlyClosed: [WindowSessionState.RecentlyClosedTab] = try loadIfPresent(url: closedURL, decoder: decoder) ?? []

        return WindowSessionState(
            tabs: tabsFile.tabs,
            selectedTabID: tabsFile.selectedTabID,
            tabGroups: groupsFile.tabGroups,
            selectedTabGroupID: groupsFile.selectedTabGroupID,
            recentlyClosed: recentlyClosed,
            tabNavigationByID: nav,
            splitView: tabsFile.splitView,
            ui: tabsFile.ui
        )
    }

    private func saveToBucket(bucketURL: URL, snapshot: WindowSessionState) throws {
        let encoder = JSONEncoder()

        let tabsFile = TabsFile(
            tabs: snapshot.tabs,
            selectedTabID: snapshot.selectedTabID,
            splitView: snapshot.splitView,
            ui: snapshot.ui
        )
        let groupsFile = GroupsFile(
            tabGroups: snapshot.tabGroups,
            selectedTabGroupID: snapshot.selectedTabGroupID
        )

        try writeAtomic(url: bucketURL.appendingPathComponent(Filenames.tabs), data: encoder.encode(tabsFile))
        try writeAtomic(url: bucketURL.appendingPathComponent(Filenames.groups), data: encoder.encode(groupsFile))
        try writeAtomic(url: bucketURL.appendingPathComponent(Filenames.nav), data: encoder.encode(snapshot.tabNavigationByID))
        try writeAtomic(url: bucketURL.appendingPathComponent(Filenames.recentlyClosed), data: encoder.encode(snapshot.recentlyClosed))

        let meta = MetaFile(schemaVersion: Self.currentBucketSchemaVersion, lastSavedAt: Date())
        try writeAtomic(url: bucketURL.appendingPathComponent(Filenames.meta), data: encoder.encode(meta))
    }

    private func applyPersistenceBudgets(_ snapshot: WindowSessionState) -> WindowSessionState {
        var tabs = snapshot.tabs
        var selectedTabID = snapshot.selectedTabID

        if tabs.isEmpty {
            let placeholder = BrowserTab()
            tabs = [placeholder]
            selectedTabID = placeholder.id
        }

        // Trim tabs but keep selected tab if possible.
        if tabs.count > Budgets.maxTabsToPersist {
            let keptPrefix = Array(tabs.prefix(Budgets.maxTabsToPersist))
            if let selectedTabID,
               !keptPrefix.contains(where: { $0.id == selectedTabID }),
               let selectedTab = tabs.first(where: { $0.id == selectedTabID }) {
                tabs = Array(keptPrefix.dropLast()) + [selectedTab]
            } else {
                tabs = keptPrefix
            }
        }

        if let currentSelectedID = selectedTabID,
           !tabs.contains(where: { $0.id == currentSelectedID }) {
            selectedTabID = tabs.first?.id
        }

        // Bound recently-closed stack.
        let recentlyClosed = Array(snapshot.recentlyClosed.prefix(Budgets.maxRecentlyClosedToPersist))

        // Drop durable nav state for tabs that won't be persisted.
        let allowedTabIDs = Set(tabs.map { $0.id })
        let tabNavigationByID = snapshot.tabNavigationByID.filter { allowedTabIDs.contains($0.key) }

        return WindowSessionState(
            tabs: tabs,
            selectedTabID: selectedTabID,
            tabGroups: snapshot.tabGroups,
            selectedTabGroupID: snapshot.selectedTabGroupID,
            recentlyClosed: recentlyClosed,
            tabNavigationByID: tabNavigationByID,
            splitView: snapshot.splitView,
            ui: snapshot.ui
        )
    }

    private func pruneOldBucketsIfNeeded(keepingMostRecent maxCount: Int) throws {
        guard maxCount > 0 else { return }
        let root = try rootURL()
        guard fileManager.fileExists(atPath: root.path) else { return }

        let children = try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        var buckets: [(url: URL, lastSavedAt: Date)] = []

        let decoder = JSONDecoder()
        for url in children {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }

            let metaURL = url.appendingPathComponent(Filenames.meta)
            if let meta: MetaFile = try? loadIfPresent(url: metaURL, decoder: decoder) {
                buckets.append((url: url, lastSavedAt: meta.lastSavedAt))
            } else {
                // Fallback: if meta is missing (older versions), use directory mod date.
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                buckets.append((url: url, lastSavedAt: values?.contentModificationDate ?? .distantPast))
            }
        }

        guard buckets.count > maxCount else { return }

        buckets.sort { $0.lastSavedAt > $1.lastSavedAt }
        let toRemove = buckets.dropFirst(maxCount)
        for bucket in toRemove {
            try? fileManager.removeItem(at: bucket.url)
        }
    }

    private func writeAtomic(url: URL, data: Data) throws {
        try data.write(to: url, options: .atomic)
    }

    private func loadLegacyWindowSessionStateIfPresent(filename: String) throws -> WindowSessionState? {
        if options.rootDirectory != nil {
            // When using a custom root, legacy load is intentionally disabled.
            return nil
        }
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = docs.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WindowSessionState.self, from: data)
    }

    private func loadIfPresent<T: Decodable>(url: URL, decoder: JSONDecoder) throws -> T? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    private static func safeDirectoryName(for rawID: String) -> String {
        // Use the raw ID when it's already path-safe and reasonably short.
        if rawID.range(of: "^[A-Za-z0-9_-]{1,128}$", options: .regularExpression) != nil {
            return rawID
        }
        // Otherwise, fall back to a stable base64url encoding.
        let data = rawID.data(using: .utf8) ?? Data()
        var s = data.base64EncodedString()
        s = s.replacingOccurrences(of: "+", with: "-")
        s = s.replacingOccurrences(of: "/", with: "_")
        s = s.replacingOccurrences(of: "=", with: "")
        let trimmed = String(s.prefix(200))
        return "b64_\(trimmed)"
    }
}
