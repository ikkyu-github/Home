import SafariLikeCoreKit
import BrowserCore
import WebKit

@MainActor
enum SceneFactory {
    static func makeCoreScene(
        sceneID: String,
        windowID: String,
        maxLive: Int = 2,
        maxConcurrentActive: Int = 2
    ) -> SafariLikeCoreKit.SceneRuntimeContext {
        let regularRegistry = SafariLikeCoreKit.TabRegistry(
            windowID: windowID,
            defaultHomeURLString: "about:blank",
            browsingProfile: .regular,
            debugLogEnabled: false,
            maxAliveWebViewsOverride: 20,
            maxConcurrentActiveWebViewsOverride: maxConcurrentActive
        )
        let privateRegistry = SafariLikeCoreKit.TabRegistry(
            windowID: windowID,
            defaultHomeURLString: "about:blank",
            browsingProfile: .private,
            debugLogEnabled: false,
            maxAliveWebViewsOverride: 20,
            maxConcurrentActiveWebViewsOverride: maxConcurrentActive
        )

        let regularPool = WebViewPool(
            label: "\(windowID).regular",
            maxLiveWebViews: maxLive,
            makeWebView: {
                let config = EngineController.shared.makeWebViewConfiguration(profile: .regular)
                return WebViewPool.makeWebView(configuration: config)
            }
        )
        let privatePool = WebViewPool(
            label: "\(windowID).private",
            maxLiveWebViews: maxLive,
            makeWebView: {
                let config = EngineController.shared.makeWebViewConfiguration(profile: .private)
                return WebViewPool.makeWebView(configuration: config)
            }
        )

        let primaryPane = PaneID.primary.rawValue
        let secondaryPane = PaneID.secondary.rawValue
        regularRegistry.registerWebViewPool(regularPool, forPane: primaryPane)
        regularRegistry.registerWebViewPool(regularPool, forPane: secondaryPane)
        privateRegistry.registerWebViewPool(privatePool, forPane: primaryPane)
        privateRegistry.registerWebViewPool(privatePool, forPane: secondaryPane)

        let heuristics = SiteHeuristicsStore()
        let budget = WebViewBudget(
            regular: .init(maxLiveWebViews: maxLive, maxConcurrentActiveWebViews: maxConcurrentActive),
            privateProfile: .init(maxLiveWebViews: maxLive, maxConcurrentActiveWebViews: maxConcurrentActive)
        )

        return SafariLikeCoreKit.SceneRuntimeContext(
            sceneIdentifier: sceneID,
            windowID: windowID,
            tabRegistry: regularRegistry,
            privateTabRegistry: privateRegistry,
            siteHeuristicsStore: heuristics,
            budget: budget
        )
    }
}
