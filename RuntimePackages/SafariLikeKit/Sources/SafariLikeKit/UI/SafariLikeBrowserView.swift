import SwiftUI
import SafariLikeCoreKit
import SafariLikeContracts
/// SwiftUI root view for embedding SafariLikeKit into your app.
///
/// `SafariLikeBrowserView` bridges a ``BrowserSceneSession`` into SwiftUI and handles internal
/// wiring of ViewModels, runtime components, and UI state without exposing those types to your app.
public struct SafariLikeBrowserView: View {
    private let session: BrowserSceneSession
    private let context: SceneRuntimeContext
    private let initialURL: String?
    @Binding private var configuration: SafariLikeConfiguration
    private let makeSettingsView: (() -> AnyView)?
    // Window-scoped registry (avoid global mutable state across scenes).
    @StateObject private var sessionRegistry = AppBrowserSessionRegistry()
    @State private var didOpenInitialURL: Bool = false
    public init(
        session: BrowserSceneSession,
        context: SceneRuntimeContext,
        initialURL: String? = nil,
        configuration: Binding<SafariLikeConfiguration>,
        makeSettingsView: (() -> AnyView)? = nil
    ) {
        self.session = session
        self.context = context
        self.initialURL = initialURL
        self._configuration = configuration
        self.makeSettingsView = makeSettingsView
    }
    public var body: some View {
        let router = SceneCommandRouter()
        let handler: (AppCommand) -> Void = { command in
            Task { @MainActor in
                let vm = session.viewModel
                let chrome = session.chrome

                let contextSnapshot = CommandContextSnapshot(
                    tabCount: vm.sessionStore.tabs.count,
                    activeTabID: vm.activeTabID,
                    tabOverviewSelectedTabID: vm.isTabOverviewVisible ? vm.activeTabID : nil,
                    isTabOverviewVisible: vm.isTabOverviewVisible,
                    isAddressBarFocused: vm.isAddressFocusedExternally,
                    isFindOnPagePresented: chrome.isFindBarPresented,
                    isSettingsPresented: chrome.isAppSettingsPresented,
                    isPrivateBrowsingEnabled: vm.isPrivateMode,
                    hasRecentlyClosedTabs: vm.sessionStore.recentlyClosed.isEmpty == false
                )

                let resolution = router.route(command, in: contextSnapshot)
                guard resolution.isHandled else { return }
                Self.apply(resolution.effects, viewModel: vm, chrome: chrome)
            }
        }

        BrowserRootView(
            viewModel: session.viewModel,
            chrome: session.chrome,
            configuration: configuration,
            makeSettingsView: makeSettingsView
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environmentObject(context)
        .environment(\.browserRuntime, session)
        .focusedSceneValue(\.safariLikeSceneCommandHandler, handler)
        .onAppear {
            sessionRegistry.registerActiveSession(self.session)
            AppWindowActions.bind(sessionRegistry: sessionRegistry)
            if !self.didOpenInitialURL,
               let urlString = self.initialURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !urlString.isEmpty,
               let url = URL(string: urlString) {
                self.didOpenInitialURL = true
                self.session.openExternalURL(url)
            }
            // Safari-like restore: snapshots-first UI, then lazily load the active tab.
            // Keep restore logic coordinator-owned (CoreKit boundary).
            Task { @MainActor in
                guard self.didOpenInitialURL == false else { return }
                await self.session.viewModel.loadActiveTabContentAfterUIReady()
            }
        }
        .onDisappear {
            sessionRegistry.unregisterSession(self.session)
            self.session.invalidateSession()
        }
    }

    @MainActor
    private static func apply(
        _ effects: [CommandEffect],
        viewModel vm: SplitBrowserViewModel,
        chrome: BrowserChromeState
    ) {
        for effect in effects {
            switch effect {
            case .focusAddressBar(selectAll: _):
                vm.requestAddressFocus()

            case .presentFindOnPage:
                chrome.isFindBarPresented = true

            case .presentSettings:
                chrome.isAppSettingsPresented = true

            case let .setTabOverviewVisible(isVisible):
                vm.setTabOverviewVisible(isVisible)

            case .newTab(inBackground: _):
                vm.newTab()

            case let .closeTab(id):
                vm.closeTab(id)

            case .reopenLastClosedTab:
                if let restoredID = vm.sessionStore.undoCloseLastTab() {
                    vm.selectTab(restoredID)
                }

            case .reload:
                vm.reload()
            case .goBack:
                vm.goBack()
            case .goForward:
                vm.goForward()

            case let .selectTabByNumber(number):
                let tabs = vm.sessionStore.tabs
                guard tabs.isEmpty == false else { break }
                let idx: Int = {
                    if number == 9 { return max(0, tabs.count - 1) }
                    return max(0, number - 1)
                }()
                guard idx < tabs.count else { break }
                vm.selectTab(tabs[idx].id)

            case .selectNextTab:
                let tabs = vm.sessionStore.tabs
                guard tabs.count > 1, let activeID = vm.activeTabID,
                      let i = tabs.firstIndex(where: { $0.id == activeID })
                else { break }
                let next = (i + 1) % tabs.count
                vm.selectTab(tabs[next].id)

            case .selectPreviousTab:
                let tabs = vm.sessionStore.tabs
                guard tabs.count > 1, let activeID = vm.activeTabID,
                      let i = tabs.firstIndex(where: { $0.id == activeID })
                else { break }
                let prev = (i - 1 + tabs.count) % tabs.count
                vm.selectTab(tabs[prev].id)

            @unknown default:
                break
            }
        }
    }
}
