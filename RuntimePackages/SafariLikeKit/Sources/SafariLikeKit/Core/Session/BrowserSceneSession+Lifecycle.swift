// ARCH-AUDIT(2026-01-22): Autosave/lifecycle wiring kept UIKit-free for SafariLikeKit. App/SafariLikeUIKit should forward UIApplication events if needed.
import Foundation
import CoreGraphics
import WebKit
import SafariLikeCoreKit
import Combine
@MainActor
extension BrowserSceneSession {
    /// Single public intent entrypoint.
    ///
    /// UI/App code must emit intents only; the runtime decides/mutates state.
    public func send(intent: BrowserRuntimeIntent) {
        switch intent {
        case .openExternalURL(let url):
            viewModel.openExternalURL(url)

        case .goBack:
            viewModel.goBack()
        case .goForward:
            viewModel.goForward()
        case .reload:
            viewModel.reload()
        case .stopLoading:
            viewModel.send(.stopLoading)

        case .newTab(let urlString, let inBackground):
            viewModel.openTab(urlString: urlString, inBackground: inBackground)
        case .selectTab(let id):
            viewModel.selectTab(id)
        case .closeTab(let id):
            viewModel.closeTab(id)

        case .focusAddressBar:
            viewModel.requestAddressFocus()
        case .setTabOverviewVisible(let isVisible):
            viewModel.setTabOverviewVisible(isVisible)
            viewModel.syncTabOverviewVisibilityToRuntime(isVisible)
        case .setTabOverviewPresentationProgress(let progress):
            viewModel.syncTabOverviewPresentationProgressToRuntime(CGFloat(progress))
        case .setSidebarVisible(let isVisible):
            viewModel.setSidebarVisible(isVisible)
        case .toggleRelated:
            viewModel.send(.toggleRelated)
        case .setRelatedVisible(let isVisible):
            viewModel.send(.setRelatedVisible(isVisible))
        case .setSplitViewEnabled(let isEnabled):
            viewModel.send(.setSplitViewEnabled(isEnabled))

        case let .updateVisiblePaneMetrics(containerWidth, containerHeight, safeInsetsWidth, safeInsetsHeight):
            viewModel.updateVisiblePaneMetrics(
                containerSize: CGSize(width: containerWidth, height: containerHeight),
                safeAreaInsets: CGSize(width: safeInsetsWidth, height: safeInsetsHeight)
            )

        case .persistSessionNow:
            // One persistence path: BrowserCore.BrowserSessionStore.
            viewModel.sessionStore.persistNow()
        case .invalidateSession:
            viewModel.invalidate()
        case .enablePlugin(let id):
            Task { [weak self] in
                guard let self else { return }
                await self.viewModel.tabManager.enablePlugin(id: id)
            }
        case .disablePlugin(let id):
            Task { [weak self] in
                guard let self else { return }
                await self.viewModel.tabManager.disablePlugin(id: id)
            }
        }
    }
    private struct WindowLayoutSignature: Equatable {
        let isSplitEnabled: Bool
        let activePane: SafariLikeCoreKit.WindowSessionState.ActivePane
        let ratioPermille: Int
        let leftTabID: UUID?
        let rightTabID: UUID?
    }
    func installWindowLayoutAutosave() {
        let tabManager = viewModel.tabManager
        tabManager.$state
            .map { state -> WindowLayoutSignature in
                let ratioPermille = Int((state.splitViewState.ratio * 1000).rounded())
                let activePane: SafariLikeCoreKit.WindowSessionState.ActivePane = (state.splitViewState.activePane == .right) ? .right : .left
                return WindowLayoutSignature(
                    isSplitEnabled: state.splitViewState.isEnabled,
                    activePane: activePane,
                    ratioPermille: ratioPermille,
                    leftTabID: state.splitViewState.leftTabID,
                    rightTabID: state.splitViewState.rightTabID
                )
            }
            .removeDuplicates()
            // Debounce to avoid excessive disk writes during live drags.
            .debounce(for: .milliseconds(450), scheduler: RunLoop.main)
            .sink { [weak self] signature in
                guard let self else { return }
                let split = SafariLikeCoreKit.WindowSessionState.SplitViewState(
                    isEnabled: signature.isSplitEnabled,
                    ratio: Double(signature.ratioPermille) / 1000.0,
                    activePane: signature.activePane,
                    leftTabID: signature.leftTabID,
                    rightTabID: signature.rightTabID
                )
                self.viewModel.sessionStore.updateSplitViewState(split)
            }
            .store(in: &windowLayoutAutosaveCancellables)
    }
    // NOTE: UIKit lifecycle hooks intentionally removed from SafariLikeKit.
    // The App / SafariLikeUIKit should call `persistSessionNow()` (and/or a dedicated hook)
    // during background/resign-active transitions.
    // MARK: - Public Facade Methods
    public func openExternalURL(_ url: URL) {
        send(intent: .openExternalURL(url))
    }
    /// Load a URL into the currently active tab.
    ///
    /// Use this for routing external URLs into the active window without creating a new tab.
    public func openURLInActiveTab(_ url: URL) {
        viewModel.open(url)
    }
    /// Create a new tab in this window and load the URL.
    ///
    /// This is intended for app-level deep link routing where a new scene (window) should
    /// open with its own tab list, and the URL should be loaded into a fresh tab.
    public func openURLInNewTab(_ url: URL, closeInitialBlankTabIfNeeded: Bool = true) {
        let existingTabIDs = viewModel.sessionStore.tabs.map(\.id)
        let blankOnlyTabID: UUID? = {
            guard closeInitialBlankTabIfNeeded else { return nil }
            guard existingTabIDs.count == 1, let only = existingTabIDs.first else { return nil }
            let tab = viewModel.sessionStore.tabs.first(where: { $0.id == only })
            let urlString = tab?.urlString.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return urlString.isEmpty ? only : nil
        }()
        let newTabID = viewModel.openTabReturningID(urlString: url.absoluteString, inBackground: false)
        if let blankOnlyTabID, blankOnlyTabID != newTabID {
            viewModel.closeTab(blankOnlyTabID)
        }
    }

    /// Reset this scene session to a single blank tab.
    ///
    /// This preserves Safari-style semantics for "open blank window" while keeping the App
    /// target free of `BrowserCore` imports (the defining module for `BrowserSessionStore`).
    public func resetToSingleBlankTab() {
        viewModel.sessionStore.replaceAllTabs([SafariLikeCoreKit.BrowserTab()], selectedTabID: nil)
    }
    public func persistSessionNow() {
        send(intent: .persistSessionNow)
    }
    public func invalidateSession() {
        send(intent: .invalidateSession)
    }
    // Mirror UI-only toggles into the single persisted WindowSessionState.
    func installUIStateAutosave() {
        viewModel.$isSidebarVisible
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] visible in
                guard let self else { return }
                var ui = self.viewModel.sessionStore.uiState
                ui.isSidebarVisible = visible
                self.viewModel.sessionStore.updateUIState(ui)
            }
            .store(in: &windowLayoutAutosaveCancellables)
        viewModel.$isRelatedVisible
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] visible in
                guard let self else { return }
                var ui = self.viewModel.sessionStore.uiState
                ui.isRelatedVisible = visible
                self.viewModel.sessionStore.updateUIState(ui)
            }
            .store(in: &windowLayoutAutosaveCancellables)
    }
}

extension BrowserSceneSession: BrowserRuntimeIntentDispatching {}
