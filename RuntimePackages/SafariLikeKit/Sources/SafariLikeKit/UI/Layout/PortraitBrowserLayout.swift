import SwiftUI
import SafariLikeUXKit
import UIKit
import SafariLikeCoreKit
import SafariLikeContracts
internal struct PortraitBrowserLayout: View {
    @ObservedObject var vm: SplitBrowserViewModel
    @EnvironmentObject private var chrome: BrowserChromeState
    @EnvironmentObject private var relatedChrome: RelatedChromeState
    let renderPolicy: RenderPolicyManager
    let configuration: SafariLikeConfiguration
    let snapshot: BrowserLayoutSnapshot
    let onSidebarSelect: (SidebarView.Item) -> Void
    private var activeTabState: BrowserTab.State? {
        let id = vm.activeTabID ?? vm.sessionStore.selectedTabID
        guard let id else { return nil }
        return vm.sessionStore.tabs.first(where: { $0.id == id })?.state
    }
    var body: some View {
        let safeAreaInsets = snapshot.effectiveSafeAreaInsets
        let shouldShowWebContent = vm.shouldShowWebContentForActiveTab
        let viewportRect = snapshot.contentViewportRect
        let viewportLocalSafeAreaInsets = EdgeInsets(
            top: 0,
            leading: safeAreaInsets.leading,
            bottom: 0,
            trailing: safeAreaInsets.trailing
        )
        ZStack(alignment: .topLeading) {
            TabRenderer(
                tabState: activeTabState,
                preferWebContent: shouldShowWebContent,
                startPage: {
                    StartPageRenderer(vm: vm, relatedChrome: relatedChrome, safeAreaInsets: viewportLocalSafeAreaInsets)
                },
                web: {
                    WebRenderer(vm: vm, webContext: vm.activeWebContextForRendering, renderPolicy: renderPolicy)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                },
                empty: {
                    EmptyBrowserPane(onNewTab: { vm.newTab() })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            )
            .frame(width: viewportRect.width, height: viewportRect.height)
            .offset(x: viewportRect.minX, y: viewportRect.minY)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            PortraitBottomBarContainer(vm: vm, chrome: chrome, relatedChrome: relatedChrome)
                .offset(y: -max(0, snapshot.effectiveSafeAreaInsets.bottom + snapshot.keyboardLift))
        }
        .overlay(alignment: .topLeading) {
            if vm.isSidebarVisible {
                let excludedBands = [snapshot.chromeBottomRect].filter { $0.height > 0.5 }
                SidebarOverlay(
                    isVisible: Binding(
                        get: { vm.isSidebarVisible },
                        set: { vm.setSidebarVisible($0) }
                    ),
                    width: configuration.sidebarWidth,
                    viewModel: vm,
                    excludedHitBands: excludedBands,
                    onSelect: onSidebarSelect
                )
            }
        }
        // No system sheet; custom draggable popup used per requirements.
    }
}

private struct PortraitBottomBarContainer: View {
    @ObservedObject var vm: SplitBrowserViewModel
    @ObservedObject var chrome: BrowserChromeState
    @ObservedObject var relatedChrome: RelatedChromeState

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)

            PhonePortraitBottomBar(
                text: Binding(
                    get: { vm.bar.addressBarViewState.textFieldText },
                    set: { newValue in
                        vm.bar.send(SafariLikeContracts.AddressBarEvent.textChanged(newValue))
                    }
                ),
                isEditing: Binding(
                    get: { vm.bar.addressBarViewState.isTextInputFocused },
                    set: { newValue in
                        if newValue {
                            vm.bar.send(SafariLikeContracts.AddressBarEvent.tapAddressBar)
                        } else {
                            vm.bar.send(SafariLikeContracts.AddressBarEvent.cancelEditing)
                        }
                    }
                ),
                onToggleSidebar: {
                    vm.toggleSidebar()
                },
                onToggleRelated: {
                    relatedChrome.toggle(animation: vm.relatedAnimation ?? .easeOut(duration: 0.25))
                },
                onPresentTabOverview: {
                    vm.presentTabOverview()
                },
                onNewTab: {
                    vm.newTab()
                },
                onBack: {
                    vm.goBack()
                },
                onForward: {
                    vm.goForward()
                },
                onReload: {
                    vm.reload()
                },
                onSubmitURL: { submittedText in
                    vm.bar.send(SafariLikeContracts.AddressBarEvent.textChanged(submittedText))
                    vm.bar.send(SafariLikeContracts.AddressBarEvent.submitAndDismissEditing)
                },
                onAddBookmark: {
                    vm.addBookmarkForActivePage()
                },
                onShare: {
                    chrome.shareCurrentPage()
                }
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}
