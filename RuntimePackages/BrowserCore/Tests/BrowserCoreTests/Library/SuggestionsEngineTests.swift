import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class SuggestionsEngineTests: XCTestCase {
    func testSuggestionsAreDeterministicAndPreferOpenTabs() async throws {
        let tmp = FileManager.default.temporaryDirectory
        let dbURL = tmp.appendingPathComponent("library-tests-\(UUID().uuidString).sqlite")
        let repo = SQLiteLibraryRepository(config: .init(databaseURL: dbURL))

        // Seed history.
        let history = HistoryEngine(repository: repo, config: .init(dedupeWindowSeconds: 0))
        await history.recordNavigationCommit(profile: .regular, urlString: "https://example.com/", title: "Example", at: Date(timeIntervalSince1970: 1000))

        let topSites = TopSitesEngine(repository: repo)
        let engine = SuggestionsEngine(repository: repo, historyEngine: history, topSitesEngine: topSites)

        let tabs = [OpenTabSnapshot(title: "Example Tab", urlString: "https://example.com/")]

        let a = await engine.suggest(profile: .regular, query: "exa", openTabs: tabs)
        let b = await engine.suggest(profile: .regular, query: "exa", openTabs: tabs)

        XCTAssertEqual(a, b)
        XCTAssertEqual(a.first?.type, .tab)
        XCTAssertEqual(a.first?.url.normalized, "https://example.com/")
    }

    func testPrivateReturnsNoSuggestions() async {
        let tmp = FileManager.default.temporaryDirectory
        let dbURL = tmp.appendingPathComponent("library-tests-\(UUID().uuidString).sqlite")
        let repo = SQLiteLibraryRepository(config: .init(databaseURL: dbURL))
        let history = HistoryEngine(repository: repo)
        let topSites = TopSitesEngine(repository: repo)
        let engine = SuggestionsEngine(repository: repo, historyEngine: history, topSitesEngine: topSites)

        let out = await engine.suggest(profile: .private, query: "example", openTabs: [])
        XCTAssertTrue(out.isEmpty)
    }
}
