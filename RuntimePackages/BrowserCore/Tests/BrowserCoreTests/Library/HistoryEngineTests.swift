import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class HistoryEngineTests: XCTestCase {
    func testHistoryDedupeByCanonicalURLAndCountsIncrement() async throws {
        let tmp = FileManager.default.temporaryDirectory
        let dbURL = tmp.appendingPathComponent("library-tests-\(UUID().uuidString).sqlite")
        let repo = SQLiteLibraryRepository(config: .init(databaseURL: dbURL))

        let history = HistoryEngine(repository: repo, config: .init(dedupeWindowSeconds: 0))

        let t0 = Date(timeIntervalSince1970: 1000)
        await history.recordNavigationCommit(profile: .regular, urlString: "https://EXAMPLE.com/", title: "A", at: t0)
        await history.recordNavigationCommit(profile: .regular, urlString: "https://example.com/#frag", title: "B", at: t0.addingTimeInterval(1))

        let results = try await repo.queryHistory(profile: .regular, query: "example", limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].visitCount, 2)
        XCTAssertEqual(results[0].url.normalized, "https://example.com/")
        XCTAssertEqual(results[0].title, "B")
    }

    func testPrivateDoesNotWriteHistory() async throws {
        let tmp = FileManager.default.temporaryDirectory
        let dbURL = tmp.appendingPathComponent("library-tests-\(UUID().uuidString).sqlite")
        let repo = SQLiteLibraryRepository(config: .init(databaseURL: dbURL))
        let history = HistoryEngine(repository: repo)

        await history.recordNavigationCommit(profile: .private, urlString: "https://example.com", title: "X")

        let results = try await repo.queryHistory(profile: .regular, query: "", limit: 10)
        XCTAssertEqual(results.count, 0)
    }
}
