import XCTest
@testable import BrowserCore

final class SessionJournalTests: XCTestCase {

    private func makeTempDir(_ name: String = UUID().uuidString) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("webOS-tests", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testAppendThenReadBackEventsEqual() async throws {
        let base = try makeTempDir()
        let journal = SessionJournal(journalID: "t1", baseDirectory: base)

        let fixedDate = Date(timeIntervalSince1970: 123)
        let fixedID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        let event = SessionJournalEvent(
            type: .tabSelected,
            timestamp: fixedDate,
            windowID: "default",
            paneID: "left",
            tabID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            url: "https://example.com",
            eventID: fixedID
        )

        await journal.appendEvent(event)

        let events = await journal.readAllEvents()
        XCTAssertEqual(events, [event])
    }

    func testReaderStopsAtTruncatedFinalRecord() async throws {
        let base = try makeTempDir()
        let journal = SessionJournal(journalID: "t2", baseDirectory: base)

        let e1 = SessionJournalEvent(
            type: .tabCreated,
            timestamp: Date(timeIntervalSince1970: 1),
            windowID: "default",
            tabID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
        )
        let e2 = SessionJournalEvent(
            type: .urlCommitted,
            timestamp: Date(timeIntervalSince1970: 2),
            windowID: "default",
            tabID: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
            url: "https://example.com/2",
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
        )

        await journal.appendEvent(e1)
        await journal.appendEvent(e2)

        // Corrupt the tail by truncating the file mid-record.
        let journalURL = base
            .appendingPathComponent("SessionJournal", isDirectory: true)
            .appendingPathComponent("t2", isDirectory: true)
            .appendingPathComponent("events.sjlog")

        let attrs = try FileManager.default.attributesOfItem(atPath: journalURL.path)
        let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
        XCTAssertGreaterThan(size, 0)

        let newSize = max(UInt64(0), size - 8)
        let handle = try FileHandle(forWritingTo: journalURL)
        try handle.truncate(atOffset: newSize)
        try handle.close()

        // New instance forces recovery path.
        let journal2 = SessionJournal(journalID: "t2", baseDirectory: base)
        let events = await journal2.readAllEvents()
        XCTAssertEqual(events, [e1])

        // Crash-safe verification: recovery should truncate the on-disk tail
        // back to the last complete record boundary.
        let repairedAttrs = try FileManager.default.attributesOfItem(atPath: journalURL.path)
        let repairedSize = (repairedAttrs[.size] as? NSNumber)?.uint64Value ?? 0
        XCTAssertLessThan(repairedSize, newSize)
    }

    func testBadTailIsRepairedByTruncation() async throws {
        let base = try makeTempDir()
        let journal = SessionJournal(journalID: "t3", baseDirectory: base)

        let e1 = SessionJournalEvent(
            type: .splitModeChanged,
            timestamp: Date(timeIntervalSince1970: 3),
            windowID: "default",
            paneID: "left",
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000031")!
        )
        let e2 = SessionJournalEvent(
            type: .tabClosed,
            timestamp: Date(timeIntervalSince1970: 4),
            windowID: "default",
            tabID: UUID(uuidString: "00000000-0000-0000-0000-000000000040")!,
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000041")!
        )

        await journal.appendEvent(e1)
        await journal.appendEvent(e2)

        let journalURL = base
            .appendingPathComponent("SessionJournal", isDirectory: true)
            .appendingPathComponent("t3", isDirectory: true)
            .appendingPathComponent("events.sjlog")

        // Smash last byte to force CRC mismatch (bad tail).
        var bytes = try Data(contentsOf: journalURL)
        XCTAssertGreaterThan(bytes.count, 1)
        bytes[bytes.count - 1] ^= 0xFF
        try bytes.write(to: journalURL, options: [])

        let journal2 = SessionJournal(journalID: "t3", baseDirectory: base)
        let firstRead = await journal2.readAllEvents()
        XCTAssertEqual(firstRead, [e1])

        // After repair, subsequent reads should be stable (no further truncation needed).
        let journal3 = SessionJournal(journalID: "t3", baseDirectory: base)
        let secondRead = await journal3.readAllEvents()
        XCTAssertEqual(secondRead, [e1])
    }

    func testReadAllEventsIncludingArchivesReadsAcrossCompaction() async throws {
        let base = try makeTempDir()
        let journal = SessionJournal(journalID: "t4", baseDirectory: base)

        let e1 = SessionJournalEvent(
            type: .tabCreated,
            timestamp: Date(timeIntervalSince1970: 1),
            windowID: "default",
            tabID: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
        )
        let e2 = SessionJournalEvent(
            type: .tabSelected,
            timestamp: Date(timeIntervalSince1970: 2),
            windowID: "default",
            paneID: "left",
            tabID: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000112")!
        )

        await journal.appendEvent(e1)
        await journal.appendEvent(e2)

        // Force compaction: move current tail to an archive segment.
        await journal.compactIfNeeded(maxTailBytes: 1)

        let e3 = SessionJournalEvent(
            type: .navigationCommitted,
            timestamp: Date(timeIntervalSince1970: 3),
            windowID: "default",
            paneID: "left",
            tabID: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            url: "https://example.com/3",
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000113")!
        )
        await journal.appendEvent(e3)

        let all = await journal.readAllEventsIncludingArchives()
        XCTAssertEqual(all, [e1, e2, e3])
    }
}
