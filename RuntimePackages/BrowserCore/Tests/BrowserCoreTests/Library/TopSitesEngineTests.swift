import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class TopSitesEngineTests: XCTestCase {
    func testPinAndReorderIsStable() async throws {
        let tmp = FileManager.default.temporaryDirectory
        let dbURL = tmp.appendingPathComponent("library-tests-\(UUID().uuidString).sqlite")
        let repo = SQLiteLibraryRepository(config: .init(databaseURL: dbURL))
        let normalizer = URLStringNormalizer()

        // Seed history.
        try await repo.recordHistoryVisit(profile: .regular, url: normalizer.canonicalize("https://a.com")!, title: "A", at: Date(timeIntervalSince1970: 1000))
        try await repo.recordHistoryVisit(profile: .regular, url: normalizer.canonicalize("https://b.com")!, title: "B", at: Date(timeIntervalSince1970: 2000))

        let engine = TopSitesEngine(repository: repo, config: .init(maxItems: 12, lookbackDays: 365))

        let a = normalizer.canonicalize("https://a.com")!
        let b = normalizer.canonicalize("https://b.com")!

        await engine.setPinned(profile: .regular, url: a, isPinned: true)
        await engine.setPinned(profile: .regular, url: b, isPinned: true)
        await engine.reorderPinned(profile: .regular, urlsInOrder: [b, a])

        let sites = await engine.computeTopSites(profile: .regular, now: Date(timeIntervalSince1970: 3000))
        let pinned = sites.filter { $0.isPinned }
        XCTAssertEqual(pinned.count, 2)
        XCTAssertEqual(pinned[0].url.normalized, b.normalized)
        XCTAssertEqual(pinned[0].orderIndex, 0)
        XCTAssertEqual(pinned[1].url.normalized, a.normalized)
        XCTAssertEqual(pinned[1].orderIndex, 1)
    }
}
