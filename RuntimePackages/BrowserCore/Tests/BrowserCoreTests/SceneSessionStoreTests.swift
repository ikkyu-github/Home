import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class SceneSessionStoreTests: XCTestCase {

    private func makeTempRoot() throws -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let root = base.appendingPathComponent("SceneSessionStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        return root
    }

    func testSaveLoadRoundTrip() async throws {
        let root = try makeTempRoot()
        let store = SceneSessionStore(options: .init(rootDirectory: root))

        let tabAID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        let tabBID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!

        let tabA = BrowserTab(id: tabAID, title: "A", urlString: "https://a.com")
        let tabB = BrowserTab(id: tabBID, title: "B", urlString: "https://b.com")

        let navA = TabNavigationState(
            entries: [NavigationEntry(urlString: "https://a.com", title: "A")],
            cursor: .init(index: 0)
        )

        let snapshot = WindowSessionState(
            tabs: [tabA, tabB],
            selectedTabID: tabBID,
            tabGroups: [],
            selectedTabGroupID: nil,
            recentlyClosed: [],
            tabNavigationByID: [tabAID: navA]
        )

        await store.saveWindowSessionState(sceneID: "scene1", snapshot: snapshot)
        let loaded = await store.loadWindowSessionState(sceneID: "scene1")

        XCTAssertEqual(loaded.tabs.map(\.id), [tabAID, tabBID])
        XCTAssertEqual(loaded.selectedTabID, tabBID)
        XCTAssertEqual(loaded.tabNavigationByID[tabAID]?.entries.map(\.urlString), ["https://a.com"])
    }

    func testCorruptTabsFileFallsBackToDefaultState() async throws {
        let root = try makeTempRoot()
        let store = SceneSessionStore(options: .init(rootDirectory: root))

        let tabID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let tab = BrowserTab(id: tabID, title: "A", urlString: "https://a.com")
        let snapshot = WindowSessionState(tabs: [tab], selectedTabID: tabID, tabGroups: [], selectedTabGroupID: nil)

        await store.saveWindowSessionState(sceneID: "scene1", snapshot: snapshot)

        let bucketURL = root
            .appendingPathComponent("sessions", isDirectory: true)
            .appendingPathComponent("scene1", isDirectory: true)
        let tabsURL = bucketURL.appendingPathComponent("tabs.json")
        try Data("not-json".utf8).write(to: tabsURL, options: .atomic)

        let loaded = await store.loadWindowSessionState(sceneID: "scene1")
        XCTAssertEqual(loaded.tabs.count, 1)
        XCTAssertEqual(loaded.tabGroups.count, 0)
    }

    func testPersistenceBudgetsTrimTabsButKeepSelected() async throws {
        let root = try makeTempRoot()
        let store = SceneSessionStore(options: .init(rootDirectory: root))

        let tabs: [BrowserTab] = (0..<150).map { idx in
            let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-00000000%04X", idx))!
            return BrowserTab(id: id, title: "T\(idx)", urlString: "https://example.com/\(idx)")
        }
        let selectedID = tabs.last!.id

        let snapshot = WindowSessionState(tabs: tabs, selectedTabID: selectedID, tabGroups: [], selectedTabGroupID: nil)
        await store.saveWindowSessionState(sceneID: "scene1", snapshot: snapshot)

        let loaded = await store.loadWindowSessionState(sceneID: "scene1")
        XCTAssertEqual(loaded.tabs.count, 100)
        XCTAssertEqual(loaded.selectedTabID, selectedID)
        XCTAssertTrue(loaded.tabs.contains(where: { $0.id == selectedID }))
    }

    func testPrunesOldSceneBuckets() async throws {
        let root = try makeTempRoot()
        let store = SceneSessionStore(options: .init(rootDirectory: root))

        for idx in 0..<15 {
            let tab = BrowserTab(title: "T\(idx)", urlString: "https://example.com/\(idx)")
            let snapshot = WindowSessionState(tabs: [tab], selectedTabID: tab.id, tabGroups: [], selectedTabGroupID: nil)
            await store.saveWindowSessionState(sceneID: "scene_\(idx)", snapshot: snapshot)
        }

        let scenes = await store.listSceneIDs()
        XCTAssertLessThanOrEqual(scenes.count, 12)
    }
}
