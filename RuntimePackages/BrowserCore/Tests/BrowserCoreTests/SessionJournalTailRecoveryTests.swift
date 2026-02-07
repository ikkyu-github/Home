import XCTest
@testable import BrowserCore

final class SessionJournalTailRecoveryTests: XCTestCase {

    func testRecoverTailIfNeededTruncatesTrailingBytes() async throws {
        let fm = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("SessionJournalTailRecoveryTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try fm.createDirectory(at: base, withIntermediateDirectories: true)

        let journalID = "test"
        let journal = SessionJournal(journalID: journalID, baseDirectory: base, fileManager: fm)

        // Write a single valid record.
        await journal.appendEvent(SessionJournalEvent(type: .tabCreated, windowID: "default", tabID: UUID()))

        let tailURL = base
            .appendingPathComponent("SessionJournal", isDirectory: true)
            .appendingPathComponent(journalID, isDirectory: true)
            .appendingPathComponent("events.sjlog")

        XCTAssertTrue(fm.fileExists(atPath: tailURL.path))

        // Corrupt the tail by appending trailing bytes (simulates a crash mid-write).
        let beforeCorrupt = (try? fm.attributesOfItem(atPath: tailURL.path)[.size] as? NSNumber)?.intValue ?? 0
        let handle = try FileHandle(forWritingTo: tailURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0xCA, 0xFE, 0xBA, 0xBE]))
        try handle.close()

        let corruptedSize = (try? fm.attributesOfItem(atPath: tailURL.path)[.size] as? NSNumber)?.intValue ?? 0
        XCTAssertGreaterThan(corruptedSize, beforeCorrupt)

        // Trigger tail recovery.
        let events = await journal.readAllEvents()
        XCTAssertFalse(events.isEmpty)

        let afterRecover = (try? fm.attributesOfItem(atPath: tailURL.path)[.size] as? NSNumber)?.intValue ?? 0
        XCTAssertEqual(afterRecover, beforeCorrupt, "Tail recovery should truncate trailing bytes back to last good offset")
    }
}
