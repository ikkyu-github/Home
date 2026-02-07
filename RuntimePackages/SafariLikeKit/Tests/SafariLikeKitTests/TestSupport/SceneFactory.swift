@testable import SafariLikeKit
import SafariLikeCoreKit
import BrowserCore
import WebKit

@MainActor
enum SceneFactory {
    static func makeKitScene(sceneIDRaw: String, windowID: String) -> (scene: SafariLikeKit.SceneRuntimeContext, manager: TabManager) {
        let normalSessionStore = BrowserSessionStore(persistence: .memory)
        let privateSessionStore = BrowserSessionStore(persistence: .memory)

        let initialActiveTabID = normalSessionStore.addTab()

        let normalTabRegistry = SafariLikeCoreKit.TabRegistry(
            windowID: windowID,
            defaultHomeURLString: "about:blank",
            browsingProfile: .regular,
            debugLogEnabled: false,
            maxAliveWebViewsOverride: 3,
            maxConcurrentActiveWebViewsOverride: 2
        )
        let privateTabRegistry = SafariLikeCoreKit.TabRegistry(
            windowID: windowID,
            defaultHomeURLString: "about:blank",
            browsingProfile: .private,
            debugLogEnabled: false,
            maxAliveWebViewsOverride: 3,
            maxConcurrentActiveWebViewsOverride: 2
        )

        let normalPool = WebViewPool(
            label: "\(windowID).regular",
            maxLiveWebViews: 2,
            makeWebView: {
                WebViewPool.makeWebView(configuration: WKWebViewConfiguration())
            }
        )
        let privatePool = WebViewPool(
            label: "\(windowID).private",
            maxLiveWebViews: 2,
            makeWebView: {
                WebViewPool.makeWebView(configuration: WKWebViewConfiguration())
            }
        )

        normalTabRegistry.registerWebViewPool(normalPool, forPane: PaneID.primary.rawValue)
        normalTabRegistry.registerWebViewPool(normalPool, forPane: PaneID.secondary.rawValue)
        privateTabRegistry.registerWebViewPool(privatePool, forPane: PaneID.primary.rawValue)
        privateTabRegistry.registerWebViewPool(privatePool, forPane: PaneID.secondary.rawValue)

        let normalPaneContexts: [PaneID: PaneContext] = [
            .primary: PaneContext(paneID: .primary, webViewPool: normalPool),
            .secondary: PaneContext(paneID: .secondary, webViewPool: normalPool)
        ]
        let privatePaneContexts: [PaneID: PaneContext] = [
            .primary: PaneContext(paneID: .primary, webViewPool: privatePool),
            .secondary: PaneContext(paneID: .secondary, webViewPool: privatePool)
        ]

        let repo = InMemoryLibraryRepository()
        let profileBox = BrowsingProfileBox(profile: .regular)
        let bookmarkStore = BookmarkStore(repository: repo, profileBox: profileBox)
        let historyStore = HistoryStore(repository: repo, profileBox: profileBox)

        let manager = TabManager(
            normalSessionStore: normalSessionStore,
            privateSessionStore: privateSessionStore,
            normalTabRegistry: normalTabRegistry,
            privateTabRegistry: privateTabRegistry,
            normalPaneContexts: normalPaneContexts,
            privatePaneContexts: privatePaneContexts,
            defaultHomeURLString: "about:blank",
            historyStore: historyStore,
            bookmarkStore: bookmarkStore,
            downloadStore: NullDownloadStore(),
            initialActiveTabID: initialActiveTabID,
            windowID: windowID
        )

        let core = SafariLikeCoreKit.SceneRuntimeContext(
            sceneIdentifier: sceneIDRaw,
            windowID: windowID,
            tabRegistry: normalTabRegistry,
            privateTabRegistry: privateTabRegistry,
            siteHeuristicsStore: SiteHeuristicsStore(),
            budget: WebViewBudget(
                regular: .init(maxLiveWebViews: 2, maxConcurrentActiveWebViews: 2),
                privateProfile: .init(maxLiveWebViews: 2, maxConcurrentActiveWebViews: 2)
            )
        )

        let scene = SafariLikeKit.SceneRuntimeContext(
            sceneID: SceneID(raw: sceneIDRaw),
            tabManager: manager,
            core: core
        )

        return (scene: scene, manager: manager)
    }
}
