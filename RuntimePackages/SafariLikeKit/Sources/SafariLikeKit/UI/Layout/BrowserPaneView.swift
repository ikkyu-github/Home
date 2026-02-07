import SwiftUI
import SafariLikeCoreKit
import SafariLikeUXKit
struct BrowserPaneView: View {
    init(viewModel: SplitBrowserViewModel, webContext _: WebContext? = nil) {
        self.viewModel = viewModel
    }

    private struct StuckGuardKey: Equatable {
        let tabID: UUID?
        let bindingState: TabManager.ActiveBindingState
        let attachmentUpdatedAt: Date
        let shouldShowWebContent: Bool
        let requiresWebView: Bool
    }
    @ObservedObject var viewModel: SplitBrowserViewModel
    @EnvironmentObject private var chrome: BrowserChromeState
    @EnvironmentObject private var context: SceneRuntimeContext
    @EnvironmentObject private var sceneMetrics: SceneMetrics
    @Environment(\.browserLayoutMode) private var layoutMode
    @State private var recoveryAttemptCount: Int = 0
    @State private var recoveryInFlight: Bool = false
    @State private var stuckGuardTriggeredWhileStuck: Bool = false
    private func deferNoAnimation(_ work: @MainActor @escaping () -> Void) {
        Task { @MainActor in
            // Ensure we never mutate during the current SwiftUI update pass.
            await Task.yield()
            withTransaction(Transaction(animation: nil)) {
                work()
            }
        }
    }
    private func retryInPlace(tabID: UUID?) {
        viewModel.retryInPlace(tabID: tabID)
    }
    private func triggerRecoveryIfNeeded(tabID: UUID, reason: String) {
        guard recoveryInFlight == false else { return }
        withTransaction(Transaction(animation: nil)) {
            recoveryInFlight = true
            recoveryAttemptCount += 1
        }
        Task { @MainActor in
            await viewModel.triggerWebViewRecovery(tabID: tabID, reason: reason)
            withTransaction(Transaction(animation: nil)) {
                recoveryInFlight = false
            }
        }
    }

    @ViewBuilder
    private func placeholderOverlay(
        tabID: UUID?,
        handle: WebViewHandle?,
        requiresWebView: Bool,
        attachmentState: WebViewAttachmentState,
        needsRecovery: Bool,
        isRealityReady: Bool
    ) -> some View {
        if requiresWebView == false {
            EmptyView()
        } else {
            // Safari-like UI contract:
            // - WebView host stays mounted whenever possible
            // - Placeholder/overlays are driven by lifecycle status + reality snapshot
            let shouldShowPlaceholder = (handle == nil) || (isRealityReady == false)

            #if DEBUG
            let _ = {
                if let handle, handle.isAlive, isRealityReady, shouldShowPlaceholder {
                    let tabIDLabel = tabID?.uuidString ?? "nil"
                    assertionFailure(
                        "[BrowserPaneView] Placeholder overlay rendered while WebView reality is ready (tabID=\(tabIDLabel), attachmentState=\(attachmentState)). Reality must gate placeholder visibility."
                    )
                }
            }()
            #endif

            if shouldShowPlaceholder == false {
                EmptyView()
            } else {
                let shouldFailFast = needsRecovery && recoveryAttemptCount >= 2
                if shouldFailFast {
                    ErrorPlaceholder(
                        reason: "WebView unavailable (ready without handle).",
                        onRetry: {
                            guard let tabID else { return }
                            triggerRecoveryIfNeeded(tabID: tabID, reason: "BrowserPaneView.failed.retry")
                        }
                    )
                } else {
                    switch attachmentState {
                    case .idle:
                        if needsRecovery, let tabID {
                            LaunchingBrowserPane(title: "Recovering…", subtitle: "Re-attaching WebView")
                                .allowsHitTesting(false)
                                .transaction { $0.animation = nil }
                                .task(id: tabID) {
                                    triggerRecoveryIfNeeded(tabID: tabID, reason: "BrowserPaneView.idle.missingHandle")
                                }
                        } else {
                            LaunchingBrowserPane(title: "Launching…", subtitle: "Preparing WebView")
                                .allowsHitTesting(false)
                                .transaction { $0.animation = nil }
                        }
                    case .attaching:
                        LaunchingBrowserPane(title: "Launching…", subtitle: "Attaching WebView")
                            .allowsHitTesting(false)
                            .transaction { $0.animation = nil }
                    case .restoring(let snapshot):
                        RestoreOverlay(snapshotData: snapshot)
                            .allowsHitTesting(false)
                            .transaction { $0.animation = nil }
                    case .timedOut:
                        TimedOutPlaceholder(onRetry: { retryInPlace(tabID: tabID) })
                    case .ready:
                        // Status says ready but the WebView cannot be mounted/rendered yet.
                        // This is an invariant breach; recover by rebinding runtime.
                        LaunchingBrowserPane(title: "Recovering…", subtitle: "Re-attaching WebView")
                            .allowsHitTesting(false)
                            .transaction { $0.animation = nil }
                            .task(id: tabID) {
                                if let tabID, needsRecovery {
                                    triggerRecoveryIfNeeded(tabID: tabID, reason: "BrowserPaneView.ready.missingHandle")
                                }
                            }
                    case .failed(let reason):
                        ErrorPlaceholder(reason: reason, onRetry: { retryInPlace(tabID: tabID) })
                    }
                }
            }
        }
    }
    var body: some View {
        let debugOverlayEnabled = UserDefaults.standard.bool(forKey: "ui.debugOverlayEnabled")
        let tabID = viewModel.activeTabID
        let bindingState = viewModel.tabManager.activeBindingState
        let handle = viewModel.activeWebViewHandleForRendering
            ?? (tabID.flatMap { viewModel.webViewHandleForRendering(tabID: $0) })
        let shouldShowWebContent = viewModel.shouldShowWebContent(tabID: tabID)
        // UI must not reach into WKWebView for renderability; rely on the published reality snapshot.
        let webViewReality: WebViewRealitySnapshot? = {
            guard let tabID else { return nil }
            return viewModel.webViewRealityIfAlive(tabID: tabID)
        }()
        let isRealityReady = webViewReality?.isRealityReady ?? false
        let hasSuperview = webViewReality?.hasSuperview ?? false
        let hasWindow = webViewReality?.hasWindow ?? false
        let realityFrame = webViewReality?.frame ?? .zero
        let lastReconcileAt: Date? = {
            guard let tabID else { return nil }
#if DEBUG
            return context.debugLastReconcileAt(tabID: tabID)
#else
            return nil
#endif
        }()
        // ✅ IMPORTANT:
        // Start Page / Empty tab ไม่ควรบังคับ attach WKWebView
        let requiresWebView: Bool = viewModel.requiresWebView(tabID: tabID)
        let attachmentState: WebViewAttachmentState = {
            guard let tabID else { return .idle }
            // ถ้าแท็บไม่ต้องใช้ WebView ให้ถือว่า "พร้อม" เพื่อไม่โชว์ attaching/timedOut overlay
            guard requiresWebView else { return .ready }
            guard let status = context.currentAttachmentStatus(),
                  status.tabID == tabID
            else { return .idle }
            return status.state
        }()
        let attachmentUpdatedAt: Date = {
            guard let tabID else { return .distantPast }
            guard requiresWebView else { return .distantPast }
            guard let status = context.currentAttachmentStatus(),
                  status.tabID == tabID
            else { return .distantPast }
            return status.updatedAt
        }()
        // Invariant breach for rendering: UI expects web content but CoreKit reports no handle.
        let needsRecovery: Bool = {
            guard tabID != nil else { return false }
            guard requiresWebView else { return false }
            guard handle == nil else { return false }
            // If we're supposed to show web content but have no handle, recover immediately.
            if shouldShowWebContent { return true }
            // If lifecycle says we're ready but we cannot render, this is a hard invariant break.
            if case .ready = attachmentState { return true }
            return false
        }()
        return ZStack {
            // Base layer: render the WebView whenever a live handle exists.
            // Attachment must be UI-driven only; it must NOT be gated by navigation/ready flags.
            if let tabID, let handle, handle.isAlive {
                WKWebViewContainerView(viewModel: viewModel, tabID: tabID, webViewHandle: handle)
            } else {
                if viewModel.sessionStore.tabs.isEmpty {
                    EmptyBrowserPane(onNewTab: { viewModel.newTab() })
                } else {
                    Color(.systemBackground)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .overlay {
            placeholderOverlay(
                tabID: tabID,
                handle: handle,
                requiresWebView: requiresWebView,
                attachmentState: attachmentState,
                needsRecovery: needsRecovery,
                isRealityReady: isRealityReady
            )
        }
        #if DEBUG
        .overlay(alignment: .topLeading) {
            if debugOverlayEnabled {
                WebViewRealityLifecycleDebugOverlay(
                    tabID: tabID,
                    attachmentState: attachmentState,
                    attachmentUpdatedAt: attachmentUpdatedAt,
                    isRealityReady: isRealityReady,
                    hasWindow: hasWindow,
                    hasSuperview: hasSuperview,
                    frame: realityFrame,
                    lastReconcileAt: lastReconcileAt
                )
                .padding(8)
            }
        }
        #endif
        .onChange(of: tabID) { _ in
            Task { @MainActor in
                await Task.yield()
                withTransaction(Transaction(animation: nil)) {
                    viewModel.reconcileWebContentVisibility(reason: "BrowserPaneView.tabID.changed")
                }
            }
            deferNoAnimation {
                recoveryAttemptCount = 0
                recoveryInFlight = false
                stuckGuardTriggeredWhileStuck = false
            }
        }
        .onChange(of: shouldShowWebContent) { _ in
            Task { @MainActor in
                await Task.yield()
                withTransaction(Transaction(animation: nil)) {
                    viewModel.reconcileWebContentVisibility(reason: "BrowserPaneView.webVisibility.changed")
                }
            }
        }
        .task(id: StuckGuardKey(
            tabID: tabID,
            bindingState: bindingState,
            attachmentUpdatedAt: attachmentUpdatedAt,
            shouldShowWebContent: shouldShowWebContent,
            requiresWebView: requiresWebView
        )) {
            guard let tabID else {
                stuckGuardTriggeredWhileStuck = false
                return
            }
            guard requiresWebView, shouldShowWebContent else {
                stuckGuardTriggeredWhileStuck = false
                return
            }
            let isStuck: Bool = {
                if case .unbound = bindingState { return true }
                if case .idle = attachmentState { return true }
                return false
            }()
            let isHealthyEnoughToReset: Bool = {
                guard case .bound = bindingState else { return false }
                switch attachmentState {
                case .idle:
                    return false
                default:
                    return true
                }
            }()
            if isHealthyEnoughToReset {
                stuckGuardTriggeredWhileStuck = false
            }
            guard isStuck else { return }
            guard stuckGuardTriggeredWhileStuck == false else { return }
            // Debounce: only recover if the tab stays unbound/idle for ~400ms.
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard Task.isCancelled == false else { return }
            guard viewModel.activeTabID == tabID else { return }
            guard requiresWebView, viewModel.shouldShowWebContent(tabID: tabID) else { return }
            let currentBinding = viewModel.tabManager.activeBindingState
            let currentAttach: WebViewAttachmentState = {
                guard let status = context.currentAttachmentStatus(),
                    status.tabID == tabID
                else { return .idle }
                return status.state
            }()
            let stillStuck: Bool = {
                if case .unbound = currentBinding { return true }
                if case .idle = currentAttach { return true }
                return false
            }()
            guard stillStuck else {
                stuckGuardTriggeredWhileStuck = false
                return
            }
            stuckGuardTriggeredWhileStuck = true
            triggerRecoveryIfNeeded(tabID: tabID, reason: "BrowserPaneView.stuck.unbound_or_idle")
        }
        .transaction { txn in
            // Never animate content swaps during launching/attaching.
            txn.animation = nil
        }
    }
}
// NOTE (Jan 2569):
// - Fixes "white screen / Launching… / Attaching WebView loop" by ensuring WKWebView is mounted
//   as soon as a live handle exists (never gated by any ready flag).
// - Launching/Attaching overlays are now dismissed based on real UIKit/WebKit renderability
//   (alive + in-window + non-zero frame + in view tree), so overlays cannot stick permanently
//   when navigation finishes but attachment state lags.
// - Any lifecycle nudges from this view are deferred with Task.yield() to avoid
//   SwiftUI runtime warnings about publishing during view updates.
private struct WKWebViewContainerView: View {
    @ObservedObject var viewModel: SplitBrowserViewModel
    let tabID: UUID
    let webViewHandle: WebViewHandle
    @EnvironmentObject private var chrome: BrowserChromeState
    @EnvironmentObject private var context: SceneRuntimeContext
    @EnvironmentObject private var sceneMetrics: SceneMetrics
    @Environment(\.browserLayoutMode) private var layoutMode
    @Environment(\.uxPolicy) private var uxPolicy
    var body: some View {
        WebView(
            webViewHandle: webViewHandle,
            realityUpdater: viewModel.runtimeRealityUpdaterIfAlive(for: tabID),
            headerView: SafariHeaderView(
                vm: viewModel,
                topBarMode: .passive,
                isLandscape: false
            ),
            topContentInset: 0,
            bottomContentInset: 0,
            onScroll: { offset, scrollView in
                chrome.handleWebScroll(contentOffset: offset, scrollView: scrollView)
                viewModel.handleWebScroll(contentOffset: offset, scrollView: scrollView)
            },
            onPullToRefresh: { viewModel.send(.reload) },
            // Provide a stable identity so UIKit bridging can force a rebind
            // across tab switches and avoid sticky attachment state.
            identity: tabID,
            edgeSwipePolicy: uxPolicy.swipeNavigation,
            onAttached: {
                viewModel.notifyWebViewAttached(tabID: tabID)
                chrome.dismissOmniboxOverlay()
            },
            onDetached: {
                viewModel.notifyWebViewDetached(tabID: tabID)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        // NOTE:
        // Avoid mutating `isHidden/alpha` from SwiftUI appear/disappear.
        // SwiftUI can emit transient disappear/appear during diffing (AttributeGraph cycles),
        // which can accidentally leave a live WKWebView invisible ("white page") even though
        // it's attached + finished loading.
    }
}
private struct TimedOutPlaceholder: View {
    let onRetry: () -> Void
    var body: some View {
        ZStack {
            SkeletonWebPlaceholder()
            VStack {
                Spacer()
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 24)
            }
        }
    }
}
private struct ErrorPlaceholder: View {
    let reason: String?
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Something went wrong")
                .font(.headline)
            if let reason, !reason.isEmpty {
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
