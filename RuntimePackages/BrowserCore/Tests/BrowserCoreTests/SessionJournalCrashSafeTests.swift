import XCTest
@testable import BrowserCore

final class SessionJournalCrashSafeTests: XCTestCase {

    private func makeTempDir(_ name: String = UUID().uuidString) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("webOS-tests", isDirectory: true)
            .appendingPathComponent("SessionJournalCrashSafeTests", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func journalURL(base: URL, journalID: String) -> URL {
        base
            .appendingPathComponent("SessionJournal", isDirectory: true)
            .appendingPathComponent(journalID, isDirectory: true)
            .appendingPathComponent("events.sjlog")
    }

    private func fixedUUID(_ n: Int) -> UUID {
        // 00000000-0000-0000-0000-000000000001 ...
        let s = String(format: "00000000-0000-0000-0000-%012d", n)
        return UUID(uuidString: s)!
    }

    func testWriteTenEventsThenReadAllEventsReturnsAll() async throws {
        let base = try makeTempDir()
        let journalID = "a1"
        let journal = SessionJournal(journalID: journalID, baseDirectory: base)

        let tabID = fixedUUID(100)
        let windowID = "default"

        let events: [SessionJournalEvent] = (1...10).map { i in
            SessionJournalEvent(
                type: .tabSelected,
                timestamp: Date(timeIntervalSince1970: TimeInterval(i)),
                windowID: windowID,
                paneID: "left",
                tabID: tabID,
                url: "https://example.com/\(i)",
                eventID: fixedUUID(i)
            )
        }

        for e in events {
            await journal.appendEvent(e)
        }

        let readBack = await journal.readAllEvents()
        XCTAssertEqual(readBack.count, 10)
        XCTAssertEqual(readBack, events)
    }

    func testTruncatedTailReturnsOnlyCompleteRecordsAndTruncatesFile() async throws {
        let fm = FileManager.default
        let base = try makeTempDir()
        let journalID = "a2"
        let journal = SessionJournal(journalID: journalID, baseDirectory: base, fileManager: fm)

        let tabID = fixedUUID(200)
        let windowID = "default"

        let events: [SessionJournalEvent] = (1...10).map { i in
            SessionJournalEvent(
                type: .urlCommitted,
                timestamp: Date(timeIntervalSince1970: TimeInterval(i)),
                windowID: windowID,
                paneID: "left",
                tabID: tabID,
                url: "https://example.com/\(i)",
                eventID: fixedUUID(1000 + i)
            )
        }

        for e in events {
            await journal.appendEvent(e)
        }

        let url = journalURL(base: base, journalID: journalID)
        XCTAssertTrue(fm.fileExists(atPath: url.path))

        let before = (try fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value ?? 0
        XCTAssertGreaterThan(before, 0)

        // Simulate crash mid-write by truncating a few bytes off the end.
        let truncatedSize = max(UInt64(0), before - 8)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: truncatedSize)
        try handle.close()

        let afterTruncate = (try fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value ?? 0
        XCTAssertEqual(afterTruncate, truncatedSize)

        // New instance forces recovery/repair path.
        let journal2 = SessionJournal(journalID: journalID, baseDirectory: base, fileManager: fm)
        let readBack = await journal2.readAllEvents()

        // Must return only complete records (drop the partial final record).
        XCTAssertEqual(readBack, Array(events.dropLast()))

        // Must truncate bad tail back to last good record boundary.
        let repaired = (try fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value ?? 0
        XCTAssertLessThan(repaired, truncatedSize)
    }

    func testCorruptedCRCTruncatesTailAndDoesNotCrash() async throws {
        let fm = FileManager.default
        let base = try makeTempDir()
        let journalID = "a3"
        let journal = SessionJournal(journalID: journalID, baseDirectory: base, fileManager: fm)

        let tabID = fixedUUID(300)
        let windowID = "default"

        let events: [SessionJournalEvent] = (1...10).map { i in
            SessionJournalEvent(
                type: .navigationCommitted,
                timestamp: Date(timeIntervalSince1970: TimeInterval(i)),
                windowID: windowID,
                paneID: "left",
                tabID: tabID,
                url: "https://example.com/\(i)",
                eventID: fixedUUID(2000 + i)
            )
        }

        for e in events {
            await journal.appendEvent(e)
        }

        let url = journalURL(base: base, journalID: journalID)
        let before = (try fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value ?? 0
        XCTAssertGreaterThan(before, 0)

        // Corrupt the last byte to trigger CRC mismatch on the final record.
        var bytes = try Data(contentsOf: url)
        XCTAssertGreaterThan(bytes.count, 1)
        bytes[bytes.count - 1] ^= 0xFF
        try bytes.write(to: url, options: [])

        // Must not crash and must drop the bad tail.
        let journal2 = SessionJournal(journalID: journalID, baseDirectory: base, fileManager: fm)
        let readBack = await journal2.readAllEvents()
        XCTAssertEqual(readBack, Array(events.dropLast()))

        // Must truncate on-disk tail back to last good record boundary.
        let repaired = (try fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value ?? 0
        XCTAssertLessThan(repaired, before)
    }
}
