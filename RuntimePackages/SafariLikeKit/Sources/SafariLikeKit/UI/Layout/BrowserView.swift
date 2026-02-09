import SwiftUI
import SafariLikeCoreKit
import SafariLikeUXKit
/// Safari-style browser layout with WKWebView as full-screen background and toolbar overlay
internal struct BrowserView: View {
    @ObservedObject var vm: SplitBrowserViewModel
    @Environment(\.browserRuntime) private var runtime
    @EnvironmentObject private var chrome: BrowserChromeState
    @EnvironmentObject private var tabOverviewTransition: TabOverviewTransitionController
    @Environment(\.keyboardHeight) private var keyboardHeight
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.isLayoutStabilizing) private var isLayoutStabilizing
    @Environment(\.uxPolicy) private var uxPolicy
    @EnvironmentObject private var sceneMetrics: SceneMetrics
    @State private var pendingGeometrySize: CGSize? = nil
    @StateObject private var renderPolicy = RenderPolicyManager()
    /// Safe area insets from the root container
    let safeAreaInsets: EdgeInsets
    /// Configuration for layout behavior
    let configuration: SafariLikeConfiguration
    /// Callback for sidebar selection in landscape
    let onSidebarSelect: (SidebarView.Item) -> Void
    var body: some View {
        GeometryReader { geo in
            let browserRootWidth = geo.size.width
            // Use ChromeController to derive effective safe-area insets.
            let effectiveSafeAreaInsets = ChromeController.effectiveSafeAreaInsets(
                provided: safeAreaInsets,
                geometryInsets: geo.safeAreaInsets
            )
            let resolution = BrowserLayoutResolver().resolve(
                containerSize: geo.size,
                safeAreaInsets: effectiveSafeAreaInsets,
                horizontalSizeClass: horizontalSizeClass,
                uxPolicy: uxPolicy,
                configuration: configuration,
                userPreference: .automatic
            )
            let isLandscape = resolution.isLandscape
            // Single source of truth for how the browser should "feel":
            // - compact portrait => phone-style chrome
            // - everything else  => iPad/Safari-style chrome
            let chromeStyle: BrowserChromeStyle = (horizontalSizeClass == .compact && isLandscape == false)
                ? .phonePortraitSafari
                : .padLandscapeSafari

            let isURLBarFocused = vm.bar.addressBarViewState.isTextInputFocused
            let keyboardLift = ChromeController.keyboardLift(
                isURLBarFocused: isURLBarFocused,
                keyboardHeight: keyboardHeight
            )

            let chromeTopHeight = SafariHeaderView.height(for: chromeStyle)

            let chromeBottomHeight: CGFloat = {
                guard chromeStyle == .phonePortraitSafari else { return 0 }
                let barBaseHeight = isURLBarFocused
                    ? PhonePortraitBottomBar.LayoutMetrics.expandedHeight
                    : PhonePortraitBottomBar.LayoutMetrics.compactHeight
                // Keep in sync with `PortraitBottomBarContainer` (divider + paddings).
                let dividerHeight: CGFloat = 1
                let topPadding: CGFloat = 8
                let bottomPadding: CGFloat = 8
                // Important: this value describes the bottom chrome itself.
                // Safe-area bottom is applied separately in `contentViewportInsets`.
                return dividerHeight + barBaseHeight + topPadding + bottomPadding
            }()

            let viewportTop: CGFloat = effectiveSafeAreaInsets.top + ((chromeStyle == .padLandscapeSafari) ? chromeTopHeight : 0)
            let viewportBottom: CGFloat = effectiveSafeAreaInsets.bottom + chromeBottomHeight + keyboardLift
            let contentViewportInsets = EdgeInsets(
                top: viewportTop,
                leading: effectiveSafeAreaInsets.leading,
                bottom: viewportBottom,
                trailing: effectiveSafeAreaInsets.trailing
            )

            let snapshot = BrowserLayoutSnapshot(
                containerSize: geo.size,
                effectiveSafeAreaInsets: effectiveSafeAreaInsets,
                stableInsets: sceneMetrics.stableInsets,
                geometrySafeAreaInsets: geo.safeAreaInsets,
                resolvedChromeStyle: chromeStyle,
                chromeHeightLimits: (chromeStyle == .padLandscapeSafari)
                    ? ChromeHeightLimits(
                        min: SafariHeaderView.height(for: chromeStyle),
                        max: SafariHeaderView.height(for: chromeStyle)
                    )
                    : nil,
                keyboardLift: keyboardLift,
                isURLBarFocused: isURLBarFocused,
                chromeTopHeight: chromeTopHeight,
                chromeBottomHeight: chromeBottomHeight,
                contentViewportInsets: contentViewportInsets,
                layoutResolution: resolution,
                tabOverviewPresentationProgress: tabOverviewTransition.presentationProgress,
                isTabOverviewVisible: vm.isTabOverviewVisible,
                isDraggingTabOverview: tabOverviewTransition.isDragging
            )
            Group {
                if horizontalSizeClass == .compact {
                    // Compact: keep the portrait vs landscape layout split.
                    if isLandscape {
                        LandscapeBrowserLayout(
                            vm: vm,
                            configuration: configuration,
                            snapshot: snapshot,
                            browserRootWidth: browserRootWidth,
                            onSidebarSelect: onSidebarSelect
                        )
                    } else {
                        PortraitBrowserLayout(
                            vm: vm,
                            renderPolicy: renderPolicy,
                            configuration: configuration,
                            snapshot: snapshot,
                            onSidebarSelect: onSidebarSelect
                        )
                    }
                } else {
                    // Regular: always use the sidebar-capable layout so Related is sidebar-only.
                    LandscapeBrowserLayout(
                        vm: vm,
                        configuration: configuration,
                        snapshot: snapshot,
                        browserRootWidth: browserRootWidth,
                        onSidebarSelect: onSidebarSelect
                    )
                }
            }
            .overlay {
                BrowserOverlayStack(
                    vm: vm,
                    chrome: chrome,
                    snapshot: snapshot,
                    configuration: configuration
                )
            }
            .animation(isLayoutStabilizing ? nil : .spring(response: 0.45, dampingFraction: 0.88), value: isLandscape)
            .observeAnimatableCGFloat(tabOverviewTransition.targetProgress) { value in
                tabOverviewTransition.updatePresentationProgress(value)
            }
            .onChange(of: vm.isTabOverviewVisible) { isVisible in
                tabOverviewTransition.syncVisibilityFromExternalChange(isVisible)
            }
            .onChange(of: tabOverviewTransition.presentationProgress) { progress in
                runtime?.send(intent: .setTabOverviewPresentationProgress(Double(progress)))
            }
            .onChange(of: geo.size) { newSize in
                if isLayoutStabilizing {
                    pendingGeometrySize = newSize
                } else {
                    pendingGeometrySize = nil
                    ChromeController.handleSizeChange(
                        viewModel: self.vm,
                        chrome: self.chrome,
                        newSize: newSize,
                        chromeStyle: chromeStyle
                    )
                }
            }
            .onChange(of: isLayoutStabilizing) { stabilizing in
                guard stabilizing == false else { return }
                guard let size = pendingGeometrySize else { return }
                pendingGeometrySize = nil
                ChromeController.handleSizeChange(
                    viewModel: self.vm,
                    chrome: self.chrome,
                    newSize: size,
                    chromeStyle: chromeStyle
                )
            }
            .onAppear {
                tabOverviewTransition.connect(
                    isVisible: Binding(
                        get: { vm.isTabOverviewVisible },
                        set: { newValue in
                            if let runtime {
                                runtime.send(intent: .setTabOverviewVisible(newValue))
                            } else {
                                vm.isTabOverviewVisible = newValue
                            }
                        }
                    )
                )
                ChromeController.handleInitialAppear(
                    viewModel: self.vm,
                    chrome: self.chrome,
                    chromeStyle: chromeStyle
                )
            }
        }
        // Full-bleed background to avoid horizontal "ghost gaps" in landscape.
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(isPresented: $chrome.isWebsiteSettingsPresented) {
            WebsiteSettingsView(vm: vm)
        }
        .sheet(isPresented: $chrome.isPrivacyReportPresented) {
            PrivacyReportView(vm: vm)
        }
        .sheet(isPresented: $chrome.isWebsiteDataPresented) {
            WebsiteDataManagementView(vm: vm)
        }
    }
}
