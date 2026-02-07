import Foundation
import Darwin
import os
import SafariLikeContracts

public typealias SessionJournalEventType = JournalEventType
public typealias SessionJournalEvent = JournalEvent

public actor SessionJournal {
    public struct Checkpoint: Codable, Sendable {
        public var schemaVersion: Int
        public var createdAt: Date
        public var reason: String
        public var tailByteOffset: UInt64
        public var state: SessionState

        public init(schemaVersion: Int, createdAt: Date, reason: String, tailByteOffset: UInt64, state: SessionState) {
            self.schemaVersion = schemaVersion
            self.createdAt = createdAt
            self.reason = reason
            self.tailByteOffset = tailByteOffset
            self.state = state
        }
    }

    private struct LegacySnapshot: Codable, Sendable {
        var sessionVersion: Int
        var createdAt: Date
        var reason: String
        var state: SessionState
    }

    public enum Durability: Sendable {
        case normal
        case critical
    }

    public static let currentCheckpointSchemaVersion: Int = 2
    public static let maxCheckpoints: Int = 3

    private let fileManager: FileManager
    private let logger = Logger(subsystem: "com.ikkyu.BrowserCore", category: "SessionJournal")
    private let metricLogger = Logger(subsystem: "com.ikkyu.BrowserCore", category: "Metrics")

    private let directoryURL: URL

    private var didRecoverTail: Bool = false

    private var journalURL: URL {
        directoryURL.appendingPathComponent("events.sjlog")
    }

    private var legacyJournalURL: URL {
        directoryURL.appendingPathComponent("events.jsonl")
    }

    /// Creates a new journal.
    ///
    /// - Parameters:
    ///   - journalID: Used to keep multiple windows/sessions separate.
    ///   - baseDirectory: Optional override for where journal files live.
    ///     Defaults to Documents/SessionJournal/<journalID> to match existing BrowserCore persistence.
    public init(journalID: String = "default", baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let root: URL
        if let baseDirectory {
            root = baseDirectory
        } else if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            root = docs
        } else {
            root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }

        self.directoryURL = root
            .appendingPathComponent("SessionJournal", isDirectory: true)
            .appendingPathComponent(journalID, isDirectory: true)
    }

    // MARK: - Public API

    /// Writes a session snapshot to disk using a rolling set of the last 3 checkpoints.
    ///
    /// Atomicity: writes to a tmp file in the same directory then renames/replaces.
    public func writeSnapshot(_ state: SessionState, reason: String) {
        do {
            try ensureDirectoryExists()
            try migrateLegacyTailIfNeeded()
            rotateCheckpoints()

            let tailOffset = try currentTailSizeBytes()

            let checkpoint = Checkpoint(
                schemaVersion: Self.currentCheckpointSchemaVersion,
                createdAt: Date(),
                reason: reason,
                tailByteOffset: tailOffset,
                state: state
            )

            let data = try makeEncoder().encode(checkpoint)
            try atomicWrite(data: data, to: checkpointURL(index: 0))
        } catch {
            #if DEBUG
            logger.error("writeSnapshot failed: \(String(describing: error), privacy: .public)")
            #endif
        }
    }

    /// Append a structured event to the crash-safe tail journal.
    public func appendEvent(_ event: SessionJournalEvent, durability: Durability = .normal) {
        do {
            try ensureDirectoryExists()
            try migrateLegacyTailIfNeeded()
            try recoverTailIfNeeded()

            if fileManager.fileExists(atPath: journalURL.path) == false {
                fileManager.createFile(atPath: journalURL.path, contents: nil)
            }

            let payload = try makeEncoder().encode(event)

            let tailFormat = detectTailFormatOnDisk()
            if tailFormat == .unknown {
                #if DEBUG
                logger.debug("appendEvent: unknown tail format, truncating to 0")
                #endif
                try? truncateTail(to: 0)
            }

            let record: Data = {
                switch tailFormat {
                case .sje1:
                    return makeRecordLegacySJE1(payload: payload)
                case .jrnl, .unknown:
                    return makeRecord(payload: payload)
                @unknown default:
                    return makeRecord(payload: payload)
                }
            }()

            #if DEBUG
            logger.debug("appendEvent type=\(String(describing: event.type), privacy: .public) payload=\(payload.count, privacy: .public) record=\(record.count, privacy: .public)")
            #endif

            // Atomic append-only write:
            // - Open with O_APPEND so each write lands at end-of-file
            // - Perform a single write per record so crashes/interleaving cannot split records
            let fd = open(journalURL.path, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR)
            if fd < 0 {
                throw CocoaError(.fileWriteUnknown)
            }
            defer {
                close(fd)
            }

            let totalWritten: Int = record.withUnsafeBytes { rawBuffer in
                guard let base = rawBuffer.baseAddress else { return -1 }
                var written = 0
                while written < rawBuffer.count {
                    let n = Darwin.write(fd, base.advanced(by: written), rawBuffer.count - written)
                    if n < 0 {
                        return -1
                    }
                    if n == 0 {
                        break
                    }
                    written += n
                }
                return written
            }
            if totalWritten != record.count {
                throw CocoaError(.fileWriteUnknown)
            }

            let shouldSync: Bool = {
                if durability == .critical { return true }
                switch event.type {
                case .tabCreated,
                     .tabClosed,
                     .tabMovedPane,
                     .tabSelected,
                     .tabSuspended,
                     .tabDiscarded,
                     .paneFocusChanged,
                     .paneFocused,
                     .paneEnteredSplit,
                     .paneExitedSplit,
                     .splitModeChanged,
                     .sidebarToggled,
                     .relatedToggled,
                     .overviewToggled,
                     .urlCommitted,
                     .navigationCommitted:
                    return true
                default:
                    return false
                }
            }()

            if shouldSync {
                // Best-effort durability for critical events.
                _ = fsync(fd)
            }
        } catch {
            #if DEBUG
            logger.error("appendEvent failed: \(String(describing: error), privacy: .public)")
            #endif
        }
    }

    /// Backward-compatible wrapper (normal durability).
    public func appendEvent(_ event: SessionJournalEvent) {
        appendEvent(event, durability: .normal)
    }

    /// Read all events currently in the tail journal.
    ///
    /// If the tail ends with a partial/corrupt record, this will truncate only the
    /// last bad record (crash-safe recovery).
    public func readAllEvents(maxBytes: Int = 2 * 1024 * 1024) -> [SessionJournalEvent] {
        do {
            try ensureDirectoryExists()
            try migrateLegacyTailIfNeeded()
            try recoverTailIfNeeded()
            guard fileManager.fileExists(atPath: journalURL.path) else { return [] }

            let data = try Data(contentsOf: journalURL, options: [.mappedIfSafe])
            if data.count > maxBytes {
                // The tail should be compacted before it grows too large.
                // Determinism > partial parsing from the middle of a framed file.
                return []
            }

            var decoded: [SessionJournalEvent] = []
            decoded.reserveCapacity(256)

            let parse = parseRecords(from: data)
            decoded.append(contentsOf: parse.events)

            if parse.didTruncateTail {
                #if DEBUG
                logger.debug("readAllEvents: bad tail detected, truncating to offset=\(parse.lastGoodOffset, privacy: .public)")
                #endif
                try truncateTail(to: parse.lastGoodOffset)
            }

            return decoded
        } catch {
            return []
        }
    }

    /// Read events after a known good byte offset (typically from a checkpoint).
    public func readEvents(afterByteOffset offset: UInt64) -> [SessionJournalEvent] {
        do {
            try ensureDirectoryExists()
            try migrateLegacyTailIfNeeded()
            try recoverTailIfNeeded()
            guard fileManager.fileExists(atPath: journalURL.path) else { return [] }

            let fileData = try Data(contentsOf: journalURL, options: [.mappedIfSafe])
            let start = Int(min(UInt64(fileData.count), offset))
            if start >= fileData.count { return [] }

            let slice = fileData.subdata(in: start..<fileData.count)
            let parse = parseRecords(from: slice)

            if parse.didTruncateTail {
                #if DEBUG
                logger.debug("readEvents(after:): bad tail detected, truncating to offset=\(UInt64(start) + parse.lastGoodOffset, privacy: .public)")
                #endif
                try truncateTail(to: UInt64(start) + parse.lastGoodOffset)
            }

            return parse.events
        } catch {
            return []
        }
    }

    /// Read all events across the full journal history (archived segments + current tail).
    ///
    /// This enables journal-only restoration without relying on state snapshots.
    ///
    /// Notes:
    /// - Archived segments are treated as immutable; crash-safe truncation is applied only
    ///   to the active tail file (`events.sjlog`).
    /// - If the total journal size exceeds `maxTotalBytes`, this returns `[]` to preserve
    ///   deterministic behavior over partial parsing.
    public func readAllEventsIncludingArchives(maxTotalBytes: Int = 8 * 1024 * 1024) -> [SessionJournalEvent] {
        do {
            try ensureDirectoryExists()
            try migrateLegacyTailIfNeeded()
            try recoverTailIfNeeded()

            var segmentURLs: [URL] = []
            segmentURLs.reserveCapacity(8)

            segmentURLs.append(contentsOf: try archivedSegmentURLsSorted())
            if fileManager.fileExists(atPath: journalURL.path) {
                segmentURLs.append(journalURL)
            }

            var totalBytes = 0
            var out: [SessionJournalEvent] = []
            out.reserveCapacity(512)

            for url in segmentURLs {
                let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                totalBytes += data.count
                if totalBytes > maxTotalBytes {
                    return []
                }

                let parse = parseRecords(from: data)
                out.append(contentsOf: parse.events)

                // Only repair the active tail file.
                if url == journalURL, parse.didTruncateTail {
                    #if DEBUG
                    logger.debug("readAllEventsIncludingArchives: bad tail detected, truncating to offset=\(parse.lastGoodOffset, privacy: .public)")
                    #endif
                    try truncateTail(to: parse.lastGoodOffset)
                }
            }

            return out
        } catch {
            return []
        }
    }

    /// Periodic compaction into snapshot + rotated tail.
    /// Never rewrites event history; it archives the current tail file.
    public func compactIfNeeded(maxTailBytes: Int = 512 * 1024) {
        do {
            try ensureDirectoryExists()
            try migrateLegacyTailIfNeeded()
            guard fileManager.fileExists(atPath: journalURL.path) else { return }
            let attrs = try fileManager.attributesOfItem(atPath: journalURL.path)
            let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
            guard size >= maxTailBytes else { return }

            let archive = directoryURL.appendingPathComponent("events.archive-\(Int(Date().timeIntervalSince1970)).sjlog")
            try fileManager.moveItem(at: journalURL, to: archive)
            fileManager.createFile(atPath: journalURL.path, contents: nil)
        } catch {
            #if DEBUG
            logger.error("compactIfNeeded failed: \(String(describing: error), privacy: .public)")
            #endif
        }
    }

    /// Reads the latest valid checkpoint from disk (newest to oldest).
    public func readLatestValidCheckpoint() -> Checkpoint? {
        do {
            try ensureDirectoryExists()

            var sawAnyCheckpoint = false

            for index in 0..<Self.maxCheckpoints {
                let url = checkpointURL(index: index)
                guard fileManager.fileExists(atPath: url.path) else { continue }

                sawAnyCheckpoint = true

                do {
                    let checkpoint = try readCheckpoint(at: url)
                    guard validate(checkpoint: checkpoint) else {
                        markCheckpointCorrupt(index: index)
                        continue
                    }
                    return checkpoint
                } catch {
                    markCheckpointCorrupt(index: index)
                    continue
                }
            }

            if sawAnyCheckpoint {
                emitMetric("session.restore.failed")
            }
            return nil
        } catch {
            emitMetric("session.restore.failed")
            return nil
        }
    }

    /// Backward-compatible helper: returns only the state from the latest valid checkpoint.
    public func readLatestValidSnapshot() -> SessionState? {
        readLatestValidCheckpoint()?.state
    }

    /// Validates a decoded checkpoint envelope.
    public func validate(checkpoint: Checkpoint, allowEmptyWindows: Bool = true) -> Bool {
        guard checkpoint.schemaVersion >= 1, checkpoint.schemaVersion <= Self.currentCheckpointSchemaVersion else { return false }

        // Basic sanity checks for the current `SessionState` schema.
        // Keep this conservative: reject obviously broken data but allow forward evolution.
        let state = checkpoint.state
        if state.windows.isEmpty { return allowEmptyWindows }

        var seenTabIDs = Set<UUID>()

        for window in state.windows {
            if window.panes.isEmpty { return false }
            if window.panes.count > 2 { return false }

            // Collect all tab IDs in the window.
            var tabIDs = Set<UUID>()
            for pane in window.panes {
                for tab in pane.tabOrder {
                    tabIDs.insert(tab.tabID)

                    if seenTabIDs.contains(tab.tabID) { return false }
                    seenTabIDs.insert(tab.tabID)
                }
            }

            if let selected = window.selectedTabID {
                guard tabIDs.contains(selected) else { return false }
            }

            for pane in window.panes {
                if pane.tabOrder.isEmpty { return false }
                if let active = pane.activeTabID {
                    guard tabIDs.contains(active) else { return false }
                }

                if pane.tabOrder.count != Set(pane.tabOrder.map(\.tabID)).count { return false }
            }
        }

        // Validate tab groups (best-effort).
        if state.tabGroups.isEmpty == false {
            let allTabIDs: Set<UUID> = Set(state.windows.flatMap { w in
                w.panes.flatMap { p in p.tabOrder.map(\.tabID) }
            })

            for group in state.tabGroups {
                // Reject obviously corrupt groups referencing missing tabs.
                for id in group.tabIDs {
                    if allTabIDs.contains(id) == false { return false }
                }
            }

            if let selectedGroup = state.selectedTabGroupID {
                guard state.tabGroups.contains(where: { $0.id == selectedGroup }) else { return false }
            }
        }

        return true
    }

    /// Removes any checkpoint files that cannot be decoded or fail validation.
    public func purgeCorruptSnapshots() {
        do {
            try ensureDirectoryExists()

            for index in 0..<Self.maxCheckpoints {
                let url = checkpointURL(index: index)
                guard fileManager.fileExists(atPath: url.path) else { continue }

                do {
                    let checkpoint = try readCheckpoint(at: url)
                    guard validate(checkpoint: checkpoint) else {
                        markCheckpointCorrupt(index: index)
                        continue
                    }
                } catch {
                    markCheckpointCorrupt(index: index)
                    continue
                }
            }
        } catch {
            // best-effort
        }
    }

    // MARK: - Internals

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func migrateLegacyTailIfNeeded() throws {
        guard fileManager.fileExists(atPath: legacyJournalURL.path) else { return }
        guard fileManager.fileExists(atPath: journalURL.path) == false else { return }

        let archive = directoryURL.appendingPathComponent("events.legacy-\(Int(Date().timeIntervalSince1970)).jsonl")
        try? fileManager.removeItem(at: archive)
        try fileManager.moveItem(at: legacyJournalURL, to: archive)
        fileManager.createFile(atPath: journalURL.path, contents: nil)
    }

    private func archivedSegmentURLsSorted() throws -> [URL] {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return [] }
        let urls = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        let archives = urls.filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("events.archive-") && name.hasSuffix(".sjlog")
        }
        // Timestamp is embedded in the filename; lexicographic order is chronological.
        return archives.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func checkpointURL(index: Int) -> URL {
        directoryURL.appendingPathComponent("checkpoint_\(index).json", isDirectory: false)
    }

    private func corruptCheckpointURL(index: Int) -> URL {
        directoryURL.appendingPathComponent("checkpoint_\(index).corrupt.json", isDirectory: false)
    }

    private func ensureDirectoryExists() throws {
        if fileManager.fileExists(atPath: directoryURL.path) { return }
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func currentTailSizeBytes() throws -> UInt64 {
        guard fileManager.fileExists(atPath: journalURL.path) else { return 0 }
        let attrs = try fileManager.attributesOfItem(atPath: journalURL.path)
        let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
        return size
    }

    private func rotateCheckpoints() {
        // Shift older checkpoints up (1->2, 0->1) and keep only the last 3.
        guard Self.maxCheckpoints > 1 else { return }

        for index in stride(from: Self.maxCheckpoints - 1, through: 1, by: -1) {
            let src = checkpointURL(index: index - 1)
            let dst = checkpointURL(index: index)

            guard fileManager.fileExists(atPath: src.path) else { continue }
            try? fileManager.removeItem(at: dst)
            try? fileManager.moveItem(at: src, to: dst)
        }
    }

    private func readCheckpoint(at url: URL) throws -> Checkpoint {
        let data = try Data(contentsOf: url)
        if let decoded = try? makeDecoder().decode(Checkpoint.self, from: data) {
            return decoded
        }

        // Legacy decode path: Snapshot -> Checkpoint
        let legacy = try makeDecoder().decode(LegacySnapshot.self, from: data)
        return Checkpoint(
            schemaVersion: 1,
            createdAt: legacy.createdAt,
            reason: legacy.reason,
            tailByteOffset: 0,
            state: legacy.state
        )
    }

    private func markCheckpointCorrupt(index: Int) {
        let src = checkpointURL(index: index)
        guard fileManager.fileExists(atPath: src.path) else { return }

        let dst = corruptCheckpointURL(index: index)
        try? fileManager.removeItem(at: dst)
        do {
            try fileManager.moveItem(at: src, to: dst)
        } catch {
            try? fileManager.removeItem(at: src)
        }
    }

    private func emitMetric(_ name: String) {
        metricLogger.error("metric: \(name, privacy: .public)")
    }

    private func atomicWrite(data: Data, to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let tmpURL = dir.appendingPathComponent(".tmp_\(UUID().uuidString).json")
        try data.write(to: tmpURL, options: [])

        if fileManager.fileExists(atPath: url.path) {
            do {
                _ = try fileManager.replaceItemAt(url, withItemAt: tmpURL)
            } catch {
                // Fallback: best-effort replace.
                try? fileManager.removeItem(at: url)
                try fileManager.moveItem(at: tmpURL, to: url)
            }
        } else {
            try fileManager.moveItem(at: tmpURL, to: url)
        }
    }

    // MARK: - Crash-safe tail record format

    // v2 (current): JRNL framing
    // MAGIC (UInt32) = 0x4A524E4C  // 'JRNL'
    // VERSION (UInt16)
    // FLAGS (UInt16)
    // LENGTH (UInt32)
    // CRC32 (UInt32) of payload
    // PAYLOAD (bytes) = JSON-encoded SessionJournalEvent
    private static let recordMagicJRNL: UInt32 = 0x4A524E4C // 'JRNL'
    private static let recordVersionJRNL: UInt16 = 1
    private static let recordHeaderSizeJRNL: Int = 16

    // v1 (legacy): SJE1 framing (kept for backward reading)
    // MAGIC (UInt32) = 'SJE1'
    // LENGTH (UInt32)
    // CRC32 (UInt32)
    // PAYLOAD
    private static let recordMagicSJE1: UInt32 = 0x534A4531 // 'SJE1'
    private static let recordHeaderSizeSJE1: Int = 12

    private static let maxRecordPayloadBytes: Int = 2 * 1024 * 1024

    private func makeRecord(payload: Data, flags: UInt16 = 0) -> Data {
        let length = UInt32(payload.count)
        let checksum = CRC32.checksum(payload)

        var out = Data(capacity: Self.recordHeaderSizeJRNL + payload.count)
        out.appendUInt32BE(Self.recordMagicJRNL)
        out.appendUInt16BE(Self.recordVersionJRNL)
        out.appendUInt16BE(flags)
        out.appendUInt32BE(length)
        out.appendUInt32BE(checksum)
        out.append(payload)
        return out
    }

    private func makeRecordLegacySJE1(payload: Data) -> Data {
        let length = UInt32(payload.count)
        let checksum = CRC32.checksum(payload)

        var out = Data(capacity: Self.recordHeaderSizeSJE1 + payload.count)
        out.appendUInt32BE(Self.recordMagicSJE1)
        out.appendUInt32BE(length)
        out.appendUInt32BE(checksum)
        out.append(payload)
        return out
    }

    private enum TailFormat {
        case jrnl
        case sje1
        case unknown
    }

    private func detectTailFormat(_ data: Data) -> TailFormat {
        guard data.count >= 4 else { return .jrnl }
        let magic = data.readUInt32BE(at: 0)
        if magic == Self.recordMagicJRNL { return .jrnl }
        if magic == Self.recordMagicSJE1 { return .sje1 }
        return .unknown
    }

    private func detectTailFormatOnDisk() -> TailFormat {
        guard fileManager.fileExists(atPath: journalURL.path) else { return .jrnl }
        guard let handle = try? FileHandle(forReadingFrom: journalURL) else { return .unknown }
        defer { try? handle.close() }
        let prefix = (try? handle.read(upToCount: 4)) ?? Data()
        return detectTailFormat(prefix)
    }

    private struct ParsedRecords {
        var events: [SessionJournalEvent]
        var didTruncateTail: Bool
        var lastGoodOffset: UInt64
    }

    private func parseRecords(from data: Data) -> ParsedRecords {
        var offset: Int = 0
        var out: [SessionJournalEvent] = []
        out.reserveCapacity(256)

        var lastGood: Int = 0
        var didTruncate = false

        let format = detectTailFormat(data)

        func markBadTailAndStop() {
            didTruncate = true
        }

        switch format {
        case .jrnl:
            while offset + Self.recordHeaderSizeJRNL <= data.count {
                let magic = data.readUInt32BE(at: offset)
                if magic != Self.recordMagicJRNL {
                    markBadTailAndStop()
                    break
                }

                let version = data.readUInt16BE(at: offset + 4)
                _ = data.readUInt16BE(at: offset + 6) // flags (reserved)
                if version != Self.recordVersionJRNL {
                    markBadTailAndStop()
                    break
                }

                let length = Int(data.readUInt32BE(at: offset + 8))
                let checksum = data.readUInt32BE(at: offset + 12)

                if length < 0 || length > Self.maxRecordPayloadBytes {
                    markBadTailAndStop()
                    break
                }

                let payloadStart = offset + Self.recordHeaderSizeJRNL
                let payloadEnd = payloadStart + length
                guard payloadEnd <= data.count else {
                    // Partial final record.
                    markBadTailAndStop()
                    break
                }

                let payload = data.subdata(in: payloadStart..<payloadEnd)
                let computed = CRC32.checksum(payload)
                guard computed == checksum else {
                    markBadTailAndStop()
                    break
                }

                if let ev = try? makeDecoder().decode(SessionJournalEvent.self, from: payload) {
                    out.append(ev)
                }

                offset = payloadEnd
                lastGood = offset
            }

        case .sje1:
            while offset + Self.recordHeaderSizeSJE1 <= data.count {
                let magic = data.readUInt32BE(at: offset)
                if magic != Self.recordMagicSJE1 {
                    markBadTailAndStop()
                    break
                }

                let length = Int(data.readUInt32BE(at: offset + 4))
                let checksum = data.readUInt32BE(at: offset + 8)

                if length < 0 || length > Self.maxRecordPayloadBytes {
                    markBadTailAndStop()
                    break
                }

                let payloadStart = offset + Self.recordHeaderSizeSJE1
                let payloadEnd = payloadStart + length
                guard payloadEnd <= data.count else {
                    markBadTailAndStop()
                    break
                }

                let payload = data.subdata(in: payloadStart..<payloadEnd)
                let computed = CRC32.checksum(payload)
                guard computed == checksum else {
                    markBadTailAndStop()
                    break
                }

                if let ev = try? makeDecoder().decode(SessionJournalEvent.self, from: payload) {
                    out.append(ev)
                }

                offset = payloadEnd
                lastGood = offset
            }

        case .unknown:
            // Unknown tail format: treat as bad tail and preserve nothing.
            didTruncate = true
        }

        // If there are trailing bytes after the last complete record, truncate them.
        if offset != data.count {
            didTruncate = true
        }

        return ParsedRecords(events: out, didTruncateTail: didTruncate, lastGoodOffset: UInt64(lastGood))
    }

    private func truncateTail(to offset: UInt64) throws {
        guard fileManager.fileExists(atPath: journalURL.path) else { return }

        // Fast path: in-place truncate.
        do {
            let handle = try FileHandle(forWritingTo: journalURL)
            try handle.truncate(atOffset: offset)
            try handle.close()
            return
        } catch {
            // Fallback: rewrite valid bytes to a tmp file and atomically replace.
            let tmp = directoryURL.appendingPathComponent("events.sjlog.tmp")
            try? fileManager.removeItem(at: tmp)

            let data = try Data(contentsOf: journalURL, options: [.mappedIfSafe])
            let safeEnd = Int(min(UInt64(data.count), offset))
            let prefix = data.subdata(in: 0..<safeEnd)
            try prefix.write(to: tmp, options: [])

            if fileManager.fileExists(atPath: journalURL.path) {
                do {
                    _ = try fileManager.replaceItemAt(journalURL, withItemAt: tmp)
                } catch {
                    // Last resort: don't delete the original unless the move succeeds.
                    let backup = directoryURL.appendingPathComponent("events.sjlog.backup-\(Int(Date().timeIntervalSince1970))")
                    try? fileManager.removeItem(at: backup)
                    try fileManager.copyItem(at: journalURL, to: backup)
                    try? fileManager.removeItem(at: journalURL)
                    try fileManager.moveItem(at: tmp, to: journalURL)
                }
            } else {
                try fileManager.moveItem(at: tmp, to: journalURL)
            }
        }
    }

    private func recoverTailIfNeeded() throws {
        guard didRecoverTail == false else { return }
        didRecoverTail = true
        guard fileManager.fileExists(atPath: journalURL.path) else { return }

        let data = try Data(contentsOf: journalURL, options: [.mappedIfSafe])
        let parse = parseRecords(from: data)
        if parse.didTruncateTail {
            let originalSize = data.count
            let newSize = Int(min(UInt64(originalSize), parse.lastGoodOffset))
            let truncatedBytes = max(0, originalSize - newSize)
            metricLogger.info(
                "recoverTail.truncate journalID=\(self.directoryURL.lastPathComponent, privacy: .public) originalBytes=\(originalSize, privacy: .public) newBytes=\(newSize, privacy: .public) truncatedBytes=\(truncatedBytes, privacy: .public) lastGoodOffset=\(parse.lastGoodOffset, privacy: .public)"
            )
            #if DEBUG
            logger.debug("recoverTail: bad tail detected, truncating to offset=\(parse.lastGoodOffset, privacy: .public)")
            #endif
            try truncateTail(to: parse.lastGoodOffset)
        }
    }
}

// MARK: - Small binary helpers

private extension Data {
    mutating func appendUInt32BE(_ value: UInt32) {
        var v = value.bigEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    mutating func appendUInt16BE(_ value: UInt16) {
        var v = value.bigEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    func readUInt32BE(at offset: Int) -> UInt32 {
        let b0 = UInt32(self[offset])
        let b1 = UInt32(self[offset + 1])
        let b2 = UInt32(self[offset + 2])
        let b3 = UInt32(self[offset + 3])
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    func readUInt16BE(at offset: Int) -> UInt16 {
        let b0 = UInt16(self[offset])
        let b1 = UInt16(self[offset + 1])
        return (b0 << 8) | b1
    }
}

private enum CRC32 {
    private static let table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                if (c & 1) != 0 {
                    c = 0xEDB88320 ^ (c >> 1)
                } else {
                    c = c >> 1
                }
            }
            return c
        }
    }()

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for b in data {
            let idx = Int((crc ^ UInt32(b)) & 0xFF)
            crc = table[idx] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}
