import SwiftUI
import UIKit
import SafariLikeCoreKit
import SafariLikeUXKit

internal struct SplitBrowserRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var sceneMetrics: SceneMetrics
    @EnvironmentObject private var relatedChrome: RelatedChromeState
    @ObservedObject private var vm: SplitBrowserViewModel
    @ObservedObject private var chrome: BrowserChromeState
    private let configuration: SafariLikeConfiguration
    let makeSettingsView: (() -> AnyView)?

    @StateObject private var tabOverviewTransition: TabOverviewTransitionController
    @StateObject private var layoutStabilizer: LayoutStabilizer
    @StateObject private var renderPolicy: RenderPolicyManager

    private enum CompanionWidthMode: Equatable { case compact, wide }
    @State private var lastDecision: CompanionPresentationDecision? = nil

    @State private var pendingPolicySafeWidth: CGFloat? = nil
    @State private var pendingPolicyContainerSize: CGSize? = nil

    @State private var lastSafeWidth: CGFloat = 0
    @State private var lastOrientation: BrowserOrientation?

    #if DEBUG
    @State private var lastLoggedRelatedPolicy: RelatedPresentationPolicy? = nil
    #endif

    public init(
        viewModel: SplitBrowserViewModel,
        chrome: BrowserChromeState,
        configuration: SafariLikeConfiguration = .default,
        makeSettingsView: (() -> AnyView)? = nil
    ) {
        self.vm = viewModel
        self.chrome = chrome
        self.configuration = configuration
        self.makeSettingsView = makeSettingsView
        self._tabOverviewTransition = StateObject(wrappedValue: TabOverviewTransitionController())
        self._layoutStabilizer = StateObject(wrappedValue: LayoutStabilizer())
        self._renderPolicy = StateObject(wrappedValue: RenderPolicyManager())
    }

    public var body: some View { rootView }

    private var rootView: some View {
        // Contract: WKWebView hosting containers must respect safe areas to preserve
        // correct hit-testing and avoid unsafe underlap. See `Docs/WKWEBVIEW_LAYOUT_CONTRACT_SCAN.md`.
        sceneDrivenContent
        .environmentObject(chrome)
        .environmentObject(tabOverviewTransition)
        .sheet(isPresented: $chrome.isAppSettingsPresented) {
            if let makeSettingsView {
                makeSettingsView()
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $chrome.isDownloadsPresented) {
            DownloadsPopoverView(chrome: chrome)
        }
    }

    private var sceneDrivenContent: some View {
        // Use scene-sourced stable values to avoid transient geometry glitches during rotation.
        let size = (sceneMetrics.stableSize != .zero) ? sceneMetrics.stableSize : UIScreen.main.bounds.size
        _ = size.width

        let insetsUI = (sceneMetrics.stableInsets != .zero) ? sceneMetrics.stableInsets : UIEdgeInsets.zero
        let insets = EdgeInsets(top: insetsUI.top, leading: insetsUI.left, bottom: insetsUI.bottom, trailing: insetsUI.right)

        let safeAdjustedSize = CGSize(
            width: max(0, size.width - insets.leading - insets.trailing),
            height: max(0, size.height - insets.top - insets.bottom)
        )

        let isSplitUIPresented = SplitViewPolicy.isSplitEnabled(for: safeAdjustedSize.width)

        let layoutResolution = BrowserLayoutResolver().resolve(
            containerSize: size,
            safeAreaInsets: insets,
            horizontalSizeClass: horizontalSizeClass,
            configuration: configuration,
            userPreference: .automatic
        )
            let isLandscape = layoutResolution.isLandscape
            _ = layoutResolution.isSplit
            let chromeStyle: BrowserChromeStyle = isLandscape ? .padLandscapeSafari : .phonePortraitSafari

            let layoutMode = BrowserLayoutMode.from(chromeStyle: chromeStyle)
            let relatedPolicy = RelatedPresentationPolicy.resolve(
                layoutMode: layoutMode,
                isVisible: relatedChrome.isVisible,
                safeWidth: layoutResolution.safeWidth,
                configuration: configuration
            )

            let relatedWantsSidebar: Bool = {
                if case .sidebar = relatedPolicy { return true }
                return false
            }()

            // Pane layout is decided once (single source of truth).
            let paneLayout = PaneLayoutResolver.resolve(
                containerSize: safeAdjustedSize,
                showRelatedRequested: (relatedChrome.isVisible && relatedWantsSidebar),
                maxRelatedWidth: 420
            )

            #if DEBUG
            DispatchQueue.main.async {
                if lastLoggedRelatedPolicy != relatedPolicy {
                    print(
                        "[SplitBrowserRootView][Related][PolicyChanged] from=\(String(describing: lastLoggedRelatedPolicy)) to=\(String(describing: relatedPolicy)) isVisible=\(relatedChrome.isVisible)"
                    )
                    lastLoggedRelatedPolicy = relatedPolicy
                }
            }
            #endif

            return HStack(spacing: 0) {
                WebContentLane(
                    vm: vm,
                    webContext: vm.activeWebContextForRendering,
                    renderPolicy: renderPolicy
                )
                    .frame(width: paneLayout.webWidth)

                if paneLayout.showRelated {
                    RelatedSidePane(vm: vm)
                        .frame(width: paneLayout.relatedWidth)
                        .transaction { txn in
                            // Never animate lane geometry.
                            txn.animation = nil
                        }
                }
            }
            .frame(width: safeAdjustedSize.width, alignment: .leading)
            .transaction { txn in
                // Never animate lane geometry.
                txn.animation = nil
            }
            .environment(\.isLayoutStabilizing, layoutStabilizer.isStabilizing)
    #if DEBUG
            .navigationPolicyOverlay()
    #endif
            .onAppear {
                applyChromeStylePolicy(chromeStyle)
            }
            .onChange(of: chromeStyle) { newValue in
                applyChromeStylePolicy(newValue)
            }
            .transaction { txn in
                // Rotation/resize can produce a rapid stream of geometry updates.
                // Disabling animations here prevents "jumps" and scroll/gesture jank.
                if layoutStabilizer.isStabilizing { txn.animation = nil }
            }
            .id(vm.uiRerenderNonce)
            .observeAnimatableCGFloat(tabOverviewTransition.targetProgress) { value in
                tabOverviewTransition.updatePresentationProgress(value)
            }
            .onChange(of: vm.isTabOverviewVisible) { isVisible in
                tabOverviewTransition.syncVisibilityFromExternalChange(isVisible)
                vm.tabManager.setTabOverviewVisible(isVisible)
            }
            .onChange(of: tabOverviewTransition.presentationProgress) { progress in
                if vm.tabManager.hasActivatedInitialVisiblePanes == false {
                    vm.tabManager.setTabOverviewVisible(false)
                    return
                }
                // Treat any non-zero progress as "overview visible" for strict render budgeting.
                vm.tabManager.setTabOverviewVisible(progress > 0.001)
            }
            .onAppear {
                lastSafeWidth = safeAdjustedSize.width
                lastOrientation = BrowserLayoutResolver.orientation(for: size)

                tabOverviewTransition.updateContainerWidth(safeAdjustedSize.width)

                // HARD RULE: The browser canvas (WKWebView) must never be hosted in a split.
                // Split UI is allowed only for non-canvas surfaces (e.g. settings/bookmarks).
                if vm.isSplitViewEnabled { vm.closeSpinView() }
                chrome.splitViewMode = .single

                self.evaluateAndApplyCompanionPolicyIfNeeded(safeWidth: safeAdjustedSize.width, containerSize: size)
                self.applySplitPolicyIfNeeded(isSplitUIPresented: isSplitUIPresented)

                vm.tabManager.updateVisiblePaneMetrics(
                    containerSize: size,
                    safeAreaInsets: CGSize(width: insets.leading + insets.trailing, height: insets.top + insets.bottom)
                )

                self.attachChromeAndMarkSceneActive()
                self.notifyRootViewAppeared()

                // SAFARI-GRADE: never start in overview/frozen state
                vm.isTabOverviewVisible = false
                vm.tabManager.setTabOverviewVisible(false)
                tabOverviewTransition.forceClosed(reason: "launch.reset.overview")

                tabOverviewTransition.connect(
                    isVisible: Binding(
                        get: { vm.isTabOverviewVisible },
                        set: { vm.isTabOverviewVisible = $0 }
                    )
                )
            }
            .onChange(of: scenePhase) { newPhase in
                self.setSceneIsActiveFromPhase(newPhase)
            }
            .onChange(of: vm.activeTabID) { _ in
                self.chrome.hookActiveTab()
            }
            .onChange(of: vm.isRelatedVisible) { isVisible in
                // Single behavior: Related is always presented by the overlay chrome state.
                // This keeps legacy ViewModel intent and UI chrome in sync and prevents
                // any layout path from treating Related as a width-reserving sibling pane.
                guard relatedChrome.isVisible != isVisible else { return }
                relatedChrome.setVisible(isVisible, animation: vm.relatedAnimation ?? .easeOut(duration: 0.25))
            }
            .onChange(of: relatedChrome.isVisible) { isVisible in
                // Mirror UI chrome state back to the ViewModel for persistence/journaling.
                if vm.isRelatedVisible != isVisible {
                    vm.isRelatedVisible = isVisible
                }

                let sidebarWasVisible = vm.isSidebarVisible
                guard isVisible else { return }

                let layoutMode = BrowserLayoutMode.from(chromeStyle: chromeStyle)
                let policy = RelatedPresentationPolicy.resolve(
                    layoutMode: layoutMode,
                    isVisible: isVisible,
                    safeWidth: layoutResolution.safeWidth,
                    configuration: configuration
                )
                #if DEBUG
                print(
                    "[SplitBrowserRootView][Related][Resolve] hSize=\(String(describing: horizontalSizeClass)) vSize=\(String(describing: verticalSizeClass)) policy=\(String(describing: policy))"
                )
                #endif

                // Overlay-only safety: guard against any unexpected coupling that flips Sidebar on when
                // Related opens in overlay mode.
                guard case .overlay = policy else { return }

                DispatchQueue.main.async {
                    guard sidebarWasVisible == false else { return }
                    guard vm.isSidebarVisible == true else { return }
                    print("[HARD][Related->SidebarGuard] Forcing isSidebarVisible=false because Related opened (was false, became true) // ห้ามลบ")
                    vm.isSidebarVisible = false
                }
            }
            .onChange(of: safeAdjustedSize) { newSize in
                let newSafeWidth = newSize.width
                let newOrientation = BrowserLayoutResolver.orientation(for: size)

                tabOverviewTransition.updateContainerWidth(newSafeWidth)

                let widthChanged = abs(newSafeWidth - lastSafeWidth) > 0.5
                let orientationChanged = (lastOrientation != newOrientation)

                guard widthChanged || orientationChanged else { return }

                lastSafeWidth = newSafeWidth
                lastOrientation = newOrientation

                layoutStabilizer.markGeometryChanged()
                pendingPolicySafeWidth = newSafeWidth
                pendingPolicyContainerSize = size
            }
            .onChange(of: layoutStabilizer.isStabilizing) { stabilizing in
                guard stabilizing == false else { return }
                guard let safeWidth = pendingPolicySafeWidth, let containerSize = pendingPolicyContainerSize else { return }
                pendingPolicySafeWidth = nil
                pendingPolicyContainerSize = nil

                tabOverviewTransition.updateContainerWidth(safeWidth)

                self.evaluateAndApplyCompanionPolicyIfNeeded(safeWidth: safeWidth, containerSize: containerSize)
                self.applySplitPolicyIfNeeded(isSplitUIPresented: SplitViewPolicy.isSplitEnabled(for: safeWidth))

                vm.tabManager.updateVisiblePaneMetrics(
                    containerSize: containerSize,
                    safeAreaInsets: CGSize(width: insets.leading + insets.trailing, height: insets.top + insets.bottom)
                )
            }
            .onChange(of: vm.didUserOverrideCompanionVisibility) { _ in
                self.evaluateAndApplyCompanionPolicyIfNeeded(safeWidth: safeAdjustedSize.width, containerSize: size)
            }
            .onChange(of: vm.isAutoCompanionEnabled) { _ in
                self.evaluateAndApplyCompanionPolicyIfNeeded(safeWidth: safeAdjustedSize.width, containerSize: size)
            }
            .onChange(of: vm.relatedItems.isEmpty) { _ in
                self.evaluateAndApplyCompanionPolicyIfNeeded(safeWidth: safeAdjustedSize.width, containerSize: size)
            }
            .onChange(of: chrome.splitViewMode) { mode in
                // HARD RULE: Never allow split mode for the browser canvas.
                if mode != .single {
                    if vm.isSplitViewEnabled { vm.closeSpinView() }
                    chrome.splitViewMode = .single
                }
            }
        }

        




    // MARK: - Layout Rules

    private func evaluateAndApplyCompanionPolicyIfNeeded(safeWidth: CGFloat, containerSize: CGSize) {
        let widthMode: CompanionWidthMode = SplitViewPolicy.isSplitEnabled(for: safeWidth) ? .wide : .compact
        let orientation = BrowserLayoutResolver.orientation(for: containerSize)

        // Keep these flags updated from the real container geometry.
        vm.isLandscapeDevice = (orientation == .landscape)
        vm.isLandscapeSplitActive = (orientation == .landscape && widthMode == .wide)

        let hasItems = (vm.relatedItems.isEmpty == false)
        let userOverride: CompanionPresentationPolicy.UserOverride = .none

        let decision = CompanionPresentationPolicy.decide(
            safeWidth: safeWidth,
            orientation: orientation,
            userOverride: userOverride,
            isAutoEnabled: vm.isAutoCompanionEnabled,
            hasItems: hasItems,
            isSidebarVisible: vm.isSidebarVisible
        )

        guard decision != lastDecision else { return }
        lastDecision = decision

        applyCompanionDecision(decision, widthMode: widthMode, orientation: orientation, userOverride: userOverride)
    }

    private func applyCompanionDecision(
        _ decision: CompanionPresentationDecision,
        widthMode: CompanionWidthMode,
        orientation: BrowserOrientation,
        userOverride: CompanionPresentationPolicy.UserOverride
    ) {
        // Compact layout should not force-close a popup presentation.
        // Only close companion overlays when policy resolves to hidden.
        if widthMode == .compact, decision.presentation == .hidden {
            vm.closeCompanion()
        }

        if vm.isCompanionVisible != decision.isCompanionVisible {
            vm.isCompanionVisible = decision.isCompanionVisible
        }
        if vm.isSidebarVisible != decision.isSidebarVisible {
            vm.isSidebarVisible = decision.isSidebarVisible
        }

        // Keep the controller mirrors in sync (best-effort); avoids drift between UI and gesture policy.
        let isLandscapeDevice = (orientation == .landscape)
        vm.companionController.isLandscapeDevice = isLandscapeDevice
        vm.companionController.isAutoCompanionEnabled = vm.isAutoCompanionEnabled
        vm.companionController.didUserOverrideCompanionVisibility = vm.didUserOverrideCompanionVisibility
        vm.companionController.updateCompanionItems(empty: vm.relatedItems.isEmpty)
    }

    private func applySplitPolicyIfNeeded(isSplitUIPresented: Bool) {
        // SAFETY (Phase 10 polish): Split view must only be toggled by explicit user action.
        // - Never auto-enable split due to rotation/resize/width.
        // - Never force-disable split when narrowing.
        // UI should call open/close (e.g. SafariCompactTopBarView toggle) when the user requests it.
        _ = isSplitUIPresented
    }

    private func setSceneIsActiveFromPhase(_ phase: ScenePhase) {
        vm.setSceneIsActive(phase == .active)
    }

    private func attachChromeAndMarkSceneActive() {
        vm.setSceneIsActive(scenePhase == .active)
        chrome.attach(to: vm)
    }

    private func notifyRootViewAppeared() {
        // UI-first restore: activate web views only after the root UI is on-screen.
        vm.notifyRootViewAppeared()
    }

    private func applyChromeStylePolicy(_ style: BrowserChromeStyle) {
        chrome.setChromeStyle(style)

        // Safari iPad landscape: fixed 2-row chrome; never collapses.
        if style == .padLandscapeSafari {
            let headerHeight = SafariHeaderView.height(for: style)
            chrome.minChromeHeight = headerHeight
            chrome.maxChromeHeight = headerHeight
            chrome.chromeHeight = headerHeight
        }
    }
}

// MARK: - Debug helpers

private struct DebugLifecycle<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()

        #if DEBUG
        print("[DebugLifecycle][Init] \(label)")
        #endif
    }

    var body: some View {
        content
            #if DEBUG
            .onAppear {
                print("[DebugLifecycle][Appear] \(label)")
            }
            #endif
    }
}
