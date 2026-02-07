import SwiftUI
import UIKit
import SafariLikeCoreKit
import SafariLikeUXKit
import WebKit

// BUILD-PERF-AUDIT(2026-01-21): Compile hotspot (UIKit/WebKit bridge + lots of generic SwiftUI glue).
// Keep debug validation behind flags; avoid adding new imports to prevent rebuild fan-out.

@MainActor
struct WebView: UIViewRepresentable {
    typealias UIViewType = UIView
    let webViewHandle: WebViewHandle
    let realityUpdater: (any WebViewRealityUpdating)?
    let headerView: SafariHeaderView
    let topContentInset: CGFloat
    let bottomContentInset: CGFloat
    let onScroll: ((CGPoint, UIScrollView) -> Void)?
    let onSwipeBack: (() -> Void)?
    let onSwipeForward: (() -> Void)?
    let canSwipeBack: (() -> Bool)?
    let canSwipeForward: (() -> Bool)?
    let onEdgeSwipeProgress: ((CGFloat, EdgeSwipeDirection) -> Void)?
    let onPullToRefresh: (() -> Void)?
    let identity: UUID
    let onFocus: (() -> Void)?
    let isActivePane: (() -> Bool)?
    let edgeSwipePolicy: UXPolicy.EdgeSwipeNavigationPolicy
    let onAttached: (() -> Void)?
    let onDetached: (() -> Void)?

    @EnvironmentObject private var sceneContext: SceneRuntimeContext

    enum EdgeSwipeDirection: Sendable {
        case back
        case forward
    }

    init(
        webViewHandle: WebViewHandle,
        realityUpdater: (any WebViewRealityUpdating)? = nil,
        headerView: SafariHeaderView,
        topContentInset: CGFloat = 0,
        bottomContentInset: CGFloat = 0,
        onScroll: ((CGPoint, UIScrollView) -> Void)? = nil,
        onSwipeBack: (() -> Void)? = nil,
        onSwipeForward: (() -> Void)? = nil,
        canSwipeBack: (() -> Bool)? = nil,
        canSwipeForward: (() -> Bool)? = nil,
        onEdgeSwipeProgress: ((CGFloat, EdgeSwipeDirection) -> Void)? = nil,
        onPullToRefresh: (() -> Void)? = nil,
        identity: UUID,
        onFocus: (() -> Void)? = nil,
        isActivePane: (() -> Bool)? = nil,
        edgeSwipePolicy: UXPolicy.EdgeSwipeNavigationPolicy = .default,
        onAttached: (() -> Void)? = nil,
        onDetached: (() -> Void)? = nil
    ) {
        self.webViewHandle = webViewHandle
        self.realityUpdater = realityUpdater
        self.headerView = headerView
        self.topContentInset = topContentInset
        self.bottomContentInset = bottomContentInset
        self.onScroll = onScroll
        self.onSwipeBack = onSwipeBack
        self.onSwipeForward = onSwipeForward
        self.canSwipeBack = canSwipeBack
        self.canSwipeForward = canSwipeForward
        self.onEdgeSwipeProgress = onEdgeSwipeProgress
        self.onPullToRefresh = onPullToRefresh
        self.identity = identity
        self.onFocus = onFocus
        self.isActivePane = isActivePane
        self.edgeSwipePolicy = edgeSwipePolicy
        self.onAttached = onAttached
        self.onDetached = onDetached
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            identity: identity,
            onScroll: onScroll,
            onSwipeBack: onSwipeBack,
            onSwipeForward: onSwipeForward,
            canSwipeBack: canSwipeBack,
            canSwipeForward: canSwipeForward,
            onEdgeSwipeProgress: onEdgeSwipeProgress,
            onPullToRefresh: onPullToRefresh,
            isActivePane: isActivePane,
            edgeSwipePolicy: edgeSwipePolicy,
            onAttached: onAttached,
            onDetached: onDetached,
            recordFirstPaintAfterAttach: { [weak sceneContext] tabID, seconds in
                sceneContext?.performanceOverlayModel.recordWebViewFirstPaintAfterAttach(tabID: tabID, seconds: seconds)
            }
        )
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        context.coordinator.attachIfNeeded(
            webViewHandle: webViewHandle,
            to: container,
            onFocus: onFocus,
            forceRebind: false
        )
        if let webView = webViewHandle.webView {
            // Ensure first mount gets the same deterministic render configuration
            // as subsequent updates.
            Self.applyDeterministicRenderingInvariants(webView)
            Self.normalizeScrollIfNeeded(webView)
        }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let identityChanged = (identity != context.coordinator.lastIdentity)
        if identityChanged {
            context.coordinator.lastIdentity = identity
            context.coordinator.didSetInitialOffset = false
        }
        context.coordinator.attachIfNeeded(
            webViewHandle: webViewHandle,
            to: uiView,
            onFocus: onFocus,
            forceRebind: identityChanged
        )
        if let webView = webViewHandle.webView {
            // Deterministic configuration: ensure scroll + rendering properties are applied
            // on every update. This avoids reuse/reattach leaving the web view in a stale
            // configuration after refactors.
            Self.applyDeterministicRenderingInvariants(webView)
            Self.normalizeScrollIfNeeded(webView)
            if let realityUpdater {
                let snapshot = WebViewRealityProbe.snapshot(tabID: identity, webView: webView)
                realityUpdater.updateReality(snapshot)
            }
            // Reality-based readiness: even if we did not reattach this update, SwiftUI may
            // have just completed layout and the WKWebView can become window+frame ready.
            // Emit a best-effort attach signal once reality is ready so lifecycle can
            // reconcile away sticky timedOut states.
            context.coordinator.attachmentCoordinator.updateReadinessIfPossible(
                webView: webView,
                container: uiView,
                identity: context.coordinator.lastIdentity
            )
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        // Only tear down our KVO linkage; never touch the scroll view's delegate.
        coordinator.scrollObservation?.invalidate()
        coordinator.scrollObservation = nil
        coordinator.loadingObservation?.invalidate()
        coordinator.loadingObservation = nil
        coordinator.boundScrollView = nil
        coordinator.attachmentCoordinator.requestDetach(container: uiView)
        if let recognizer = coordinator.focusTapRecognizer {
            uiView.removeGestureRecognizer(recognizer)
        }
        coordinator.focusTapRecognizer = nil
        if let recognizer = coordinator.edgePan {
            uiView.removeGestureRecognizer(recognizer)
        }
        coordinator.edgePan = nil
        coordinator.onFocus = nil
    }
}
