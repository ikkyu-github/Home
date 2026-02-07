import Foundation
import UIKit
import SafariLikeCoreKit
import SafariLikeUXKit
import WebKit

@MainActor
extension WebView {
    static func applyDeterministicRenderingInvariants(_ webView: WKWebView) {
        // Rendering: avoid opaque/system backgrounds masking actual content.
        webView.isOpaque = false
        webView.backgroundColor = .clear
        if #available(iOS 15.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        let scroll = webView.scrollView
        scroll.backgroundColor = .clear
        // Insets: single source of truth is the container bounds.
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.automaticallyAdjustsScrollIndicatorInsets = false
        scroll.contentInset = .zero
        scroll.scrollIndicatorInsets = .zero
        scroll.verticalScrollIndicatorInsets = .zero
        scroll.horizontalScrollIndicatorInsets = .zero
    }

    static func normalizeScrollIfNeeded(_ webView: WKWebView) {
        let scroll = webView.scrollView
        let maxY = max(0, scroll.contentSize.height - scroll.bounds.height)
        if scroll.contentOffset.y > maxY {
            scroll.setContentOffset(CGPoint(x: 0, y: maxY), animated: false)
        }
    }
}

@MainActor
private final class WebViewAttachmentTracker {
    /// SAFE SINGLETON:
    /// - Process-wide best-effort invariant checker.
    /// - Tracks attached WKWebView object identities only (no scene/tab keys).
    static let shared = WebViewAttachmentTracker()
    private var attached: Set<ObjectIdentifier> = []
    private init() {}
    func didAttach(_ webView: WKWebView) {
        #if DEBUG
        if webView.safariLikeWasAllocatedByWebViewPool == false {
            Diagnostics.logError(
                "[WebViewAllocator] WKWebView attached but not allocated by WebViewPool.makeWebView(configuration:). This is an architecture violation.",
                subsystem: .runtime,
                category: "WebViewAllocator"
            )
            assertionFailure("WKWebView must be created via WebViewPool.makeWebView(configuration:)")
        }
        #endif
        attached.insert(ObjectIdentifier(webView))
        validate()
    }
    func didDetach(_ webView: WKWebView) {
        attached.remove(ObjectIdentifier(webView))
        validate()
    }
    private func validate() {
        #if DEBUG
        if attached.count > BrowserPolicy.maxConcurrentViews {
            Diagnostics.logError(
                "[WebViewBudget] attached WKWebView count exceeded budget count=\(attached.count) budget=\(BrowserPolicy.maxConcurrentViews)",
                subsystem: .runtime,
                category: "WebViewBudget"
            )
            assertionFailure("WKWebView attached count exceeded BrowserPolicy.maxConcurrentViews")
        }
        #endif
    }
}

// MARK: - Attachment State Machine (PR-05)
//
// Goal: deterministic, idempotent WKWebView attach/detach with no async re-entrancy.
//
// States:
// - idle:      no WKWebView is bound to the container.
// - attaching: a WKWebView has been attached to the container, but is not yet "reality ready"
//              (window + non-zero frame/bounds).
// - ready:     WKWebView is attached and reality-ready; `onAttached` may fire once.
// - detaching: detach requested; view hierarchy teardown is in progress.
// - restoring: transient SwiftUI unbind (handle nil) while we intentionally keep the last
//              attached WKWebView in hierarchy to avoid orphaning (superview == nil).
// - failed:    invariant breach; best-effort repair attempted, but no state commits allowed
//              from outdated async tasks.
//
// Allowed transitions (illegal transitions are ignored as no-ops):
// - idle -> attaching (requestAttach)
// - attaching -> ready (realityReady)
// - attaching -> detaching (requestDetach)
// - ready -> detaching (requestDetach)
// - ready -> restoring (requestRestore)
// - restoring -> attaching/ready (requestAttach + realityReady)
// - detaching -> idle (didDetach)
// - any -> failed (invariantBreach)
//
// Idempotency rules:
// - Repeated requestAttach for same (webView, container, identity) is a no-op.
// - requestDetach is safe in any state; it cancels all in-flight attach tasks.
// - Outdated async tasks (post-layout ready checks, deferred callbacks) must not commit.
//
// Single writer rule:
// Only `WebViewAttachmentCoordinator` below mutates the attachment state and view hierarchy.

// MARK: - Single-writer attachment coordinator

@MainActor
final class WebViewAttachmentCoordinator {
    enum State: String, Sendable {
        case idle
        case attaching
        case ready
        case detaching
        case restoring
        case failed
    }

    struct Token: Sendable, Equatable {
        let value: UInt64
    }

    struct AttachNotificationKey: Hashable, Sendable {
        let identity: UUID
        let webViewID: ObjectIdentifier
    }

    struct AttachOutcome: Sendable {
        let didMutateHierarchy: Bool
        let forceRewire: Bool
    }

    private(set) var state: State = .idle
    private var lastEmittedState: State?
    private var generation: UInt64 = 0

    private weak var boundWebView: WKWebView?
    private weak var boundContainer: UIView?
    private var boundIdentity: UUID?

    private var didNotifyAttachForKey: Set<AttachNotificationKey> = []
    #if DEBUG
    private var attachStartNanosByKey: [AttachNotificationKey: UInt64] = [:]
    private var recordFirstPaintAfterAttach: (@MainActor (_ tabID: UUID, _ seconds: Double) -> Void)?
    #endif

    private var onAttached: (() -> Void)?
    private var onDetached: (() -> Void)?

    var currentToken: Token { Token(value: generation) }
    func isTokenCurrent(_ token: Token) -> Bool { token.value == generation }

    var currentWebView: WKWebView? { boundWebView }

    func setCallbacks(onAttached: (() -> Void)?, onDetached: (() -> Void)?) {
        self.onAttached = onAttached
        self.onDetached = onDetached
    }

    #if DEBUG
    func setPerformanceRecorder(
        _ recorder: (@MainActor (_ tabID: UUID, _ seconds: Double) -> Void)?
    ) {
        self.recordFirstPaintAfterAttach = recorder
    }
    #endif

    func requestRestore(container: UIView) {
        // Transient nil handle during SwiftUI diffing: keep hierarchy intact.
        transition(to: .restoring)
        boundContainer = container
        generation &+= 1
    }

    func requestDetach(container: UIView) {
        // Idempotency: if we're already detached/idle, do not emit callbacks or mutate.
        if state == .idle, boundWebView == nil {
            if DiagnosticsGate.isEnabled {
                Diagnostics.logDebug(
                    "[WebViewAttach] detach.noop state=idle container=\(ObjectIdentifier(container))",
                    subsystem: .web,
                    category: "Attachment"
                )
            }
            boundContainer = container
            return
        }
        generation &+= 1
        transition(to: .detaching)

        if let webView = boundWebView {
            WebViewAttachmentTracker.shared.didDetach(webView)
            if webView.superview != nil {
                webView.removeFromSuperview()
            }
        }

        boundWebView = nil
        boundContainer = container
        boundIdentity = nil
        didNotifyAttachForKey.removeAll()
        transition(to: .idle)
        deferDetachedCallback(token: currentToken)
    }

    func requestAttach(
        webView: WKWebView,
        container: UIView,
        identity: UUID,
        forceRebind: Bool,
        isActivePane: (() -> Bool)?
    ) -> AttachOutcome {
        // Bump generation to cancel any in-flight attach/detach readiness work.
        generation &+= 1
        let token = currentToken

        let previous = boundWebView
        let containerChanged = (boundContainer !== container)
        let webViewChanged = (previous !== webView)
        let needsAttach = (webView.superview !== container)
        let shouldMutateHierarchy = needsAttach || webViewChanged || containerChanged || forceRebind

        boundWebView = webView
        boundContainer = container
        boundIdentity = identity

        // Idempotency: same webview already attached and ready-ish.
        if shouldMutateHierarchy == false {
            if DiagnosticsGate.isEnabled {
                Diagnostics.logDebug(
                    "[WebViewAttach] attach.noop id=\(identity.uuidString) webView=\(ObjectIdentifier(webView)) container=\(ObjectIdentifier(container)) state=\(state.rawValue)",
                    subsystem: .web,
                    category: "Attachment"
                )
            }
            return AttachOutcome(didMutateHierarchy: false, forceRewire: false)
        }

        transition(to: .attaching)

        // Detach previous bound webview (if any).
        if webViewChanged, let previous {
            WebViewAttachmentTracker.shared.didDetach(previous)
            if previous.superview != nil {
                previous.removeFromSuperview()
            }
        }

        // Hard rule: container must host exactly one WKWebView.
        if container.subviews.isEmpty == false {
            container.subviews.forEach { $0.removeFromSuperview() }
        }
        if container.constraints.isEmpty == false {
            NSLayoutConstraint.deactivate(container.constraints)
        }

        // Attach deterministically.
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        container.setNeedsLayout()
        container.layoutIfNeeded()

        WebView.applyDeterministicRenderingInvariants(webView)
        WebView.normalizeScrollIfNeeded(webView)
        WebViewAttachmentTracker.shared.didAttach(webView)

        #if DEBUG
        let key = AttachNotificationKey(identity: identity, webViewID: ObjectIdentifier(webView))
        attachStartNanosByKey[key] = DispatchTime.now().uptimeNanoseconds
        #endif

        // If container bounds were transiently zero, schedule a post-layout readiness check.
        if container.bounds.isEmpty {
            Task { @MainActor [weak self, weak webView, weak container] in
                await Task.yield()
                guard let self, self.isTokenCurrent(token) else { return }
                guard let webView, let container else { return }
                self.updateReadinessIfPossible(webView: webView, container: container, identity: identity)
            }
        }

        // Also attempt readiness now (idempotent if not yet ready).
        updateReadinessIfPossible(webView: webView, container: container, identity: identity)

        // If we were asked to force-rebind, let higher layers rewire observations.
        return AttachOutcome(didMutateHierarchy: true, forceRewire: forceRebind)
    }

    func updateReadinessIfPossible(webView: WKWebView, container: UIView, identity: UUID) {
        guard boundWebView === webView else { return }
        guard boundContainer === container else { return }

        // Best-effort: ask UIKit to finish layout before we decide readiness.
        container.layoutIfNeeded()

        guard isRealityReady(webView: webView, container: container) else { return }

        let key = AttachNotificationKey(identity: identity, webViewID: ObjectIdentifier(webView))
        guard didNotifyAttachForKey.contains(key) == false else { return }
        didNotifyAttachForKey.insert(key)

        transition(to: .ready)

        #if DEBUG
        if let start = attachStartNanosByKey[key] {
            let end = DispatchTime.now().uptimeNanoseconds
            let seconds = Double(end &- start) / 1_000_000_000
            recordFirstPaintAfterAttach?(identity, seconds)
            attachStartNanosByKey[key] = nil
        }
        #endif

        deferAttachedCallback(token: currentToken)
    }

    func repairInvariant(webView: WKWebView, container: UIView) {
        // Only repair for the currently-bound pair.
        guard boundWebView === webView else { return }
        guard boundContainer === container else { return }
        guard let boundIdentity else { return }
        generation &+= 1
        let token = currentToken

        transition(to: .failed)
        // SwiftUI can recreate the container UIView while the WKWebView is reused.
        // Repair invariant: WKWebView must be attached to the *current* container.
        webView.removeFromSuperview()
        if container.subviews.isEmpty == false {
            container.subviews.forEach { $0.removeFromSuperview() }
        }
        if container.constraints.isEmpty == false {
            NSLayoutConstraint.deactivate(container.constraints)
        }
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        container.setNeedsLayout()
        container.layoutIfNeeded()

        // Attempt readiness again after repair (still token-gated).
        Task { @MainActor [weak self, weak webView, weak container] in
            await Task.yield()
            guard let self, self.isTokenCurrent(token) else { return }
            guard let webView, let container else { return }
            self.updateReadinessIfPossible(webView: webView, container: container, identity: boundIdentity)
        }
    }

    private func isRealityReady(webView: WKWebView, container: UIView) -> Bool {
        guard webView.superview != nil else { return false }
        guard webView.window != nil else { return false }
        guard webView.frame.isEmpty == false else { return false }
        guard container.bounds.isEmpty == false else { return false }
        return true
    }

    private func transition(to newState: State) {
        // Illegal transitions are ignored as no-ops.
        let allowed: Bool
        switch (state, newState) {
        case (_, .failed):
            allowed = true
        case (.failed, .attaching), (.failed, .detaching), (.failed, .restoring), (.failed, .idle):
            allowed = true
        case (.idle, .attaching):
            allowed = true
        case (.attaching, .ready), (.attaching, .detaching), (.attaching, .restoring):
            allowed = true
        case (.ready, .detaching), (.ready, .restoring):
            allowed = true
        case (.restoring, .attaching), (.restoring, .ready), (.restoring, .detaching):
            allowed = true
        case (.detaching, .idle):
            allowed = true
        case (.idle, .restoring):
            allowed = true
        default:
            allowed = false
        }

        guard allowed else { return }
        state = newState
        emitIfChanged(newState)
    }

    private func emitIfChanged(_ state: State) {
        guard lastEmittedState != state else { return }
        lastEmittedState = state
    }

    private func deferAttachedCallback(token: Token) {
        guard onAttached != nil else { return }
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.isTokenCurrent(token) else { return }
            self.onAttached?()
        }
    }

    private func deferDetachedCallback(token: Token) {
        guard onDetached != nil else { return }
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.isTokenCurrent(token) else { return }
            self.onDetached?()
        }
    }
}

@MainActor
extension WebView {
    @MainActor
    final class Coordinator: NSObject {
        var focusTapRecognizer: UITapGestureRecognizer?
        var onFocus: (() -> Void)?
        var edgePan: UIPanGestureRecognizer?

        var activeEdgeDirection: WebView.EdgeSwipeDirection?
        var edgeProgress: CGFloat = 0
        var didCommitEdgeSwipe: Bool = false

        let edgeSwipePolicy: UXPolicy.EdgeSwipeNavigationPolicy

        var lastIdentity: UUID
        let onAttached: (() -> Void)?
        let onDetached: (() -> Void)?

        let attachmentCoordinator = WebViewAttachmentCoordinator()
        private let recordFirstPaintAfterAttach: (@MainActor (_ tabID: UUID, _ seconds: Double) -> Void)?

        private let onScroll: ((CGPoint, UIScrollView) -> Void)?
        let onSwipeBack: (() -> Void)?
        let onSwipeForward: (() -> Void)?
        let canSwipeBack: (() -> Bool)?
        let canSwipeForward: (() -> Bool)?
        let onEdgeSwipeProgress: ((CGFloat, WebView.EdgeSwipeDirection) -> Void)?
        private let onPullToRefresh: (() -> Void)?
        let isActivePane: (() -> Bool)?

        var scrollObservation: NSKeyValueObservation?
        weak var boundScrollView: UIScrollView?
        var loadingObservation: NSKeyValueObservation?

        // Coalesce extremely chatty contentOffset KVO to 1 callback per runloop tick.
        // This prevents SwiftUI state churn (and visible stutter) when the bottom bar
        // reacts to scroll.
        private var pendingScrollCallback = false
        private var latestContentOffset: CGPoint = .zero

        // We only want to set the initial contentOffset once, otherwise you'll get jumpy scroll.
        var didSetInitialOffset = false

        init(
            identity: UUID,
            onScroll: ((CGPoint, UIScrollView) -> Void)?,
            onSwipeBack: (() -> Void)?,
            onSwipeForward: (() -> Void)?,
            canSwipeBack: (() -> Bool)?,
            canSwipeForward: (() -> Bool)?,
            onEdgeSwipeProgress: ((CGFloat, WebView.EdgeSwipeDirection) -> Void)?,
            onPullToRefresh: (() -> Void)?,
            isActivePane: (() -> Bool)?,
            edgeSwipePolicy: UXPolicy.EdgeSwipeNavigationPolicy,
            onAttached: (() -> Void)?,
            onDetached: (() -> Void)?,
            recordFirstPaintAfterAttach: (@MainActor (_ tabID: UUID, _ seconds: Double) -> Void)?
        ) {
            self.lastIdentity = identity
            self.onScroll = onScroll
            self.onSwipeBack = onSwipeBack
            self.onSwipeForward = onSwipeForward
            self.canSwipeBack = canSwipeBack
            self.canSwipeForward = canSwipeForward
            self.onEdgeSwipeProgress = onEdgeSwipeProgress
            self.onPullToRefresh = onPullToRefresh
            self.isActivePane = isActivePane
            self.edgeSwipePolicy = edgeSwipePolicy
            self.onAttached = onAttached
            self.onDetached = onDetached
            self.recordFirstPaintAfterAttach = recordFirstPaintAfterAttach
            super.init()

            // Wire callbacks into the single-writer attachment coordinator.
            attachmentCoordinator.setCallbacks(
                onAttached: onAttached,
                onDetached: onDetached
            )
            attachmentCoordinator.setPerformanceRecorder(recordFirstPaintAfterAttach)
        }

        private func installPullToRefreshIfNeeded(on webView: WKWebView) {
            guard onPullToRefresh != nil else { return }
            let scrollView = webView.scrollView
            if scrollView.refreshControl == nil {
                let control = UIRefreshControl()
                control.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
                scrollView.refreshControl = control
            }
            // End refreshing when the WKWebView finishes loading.
            if loadingObservation == nil {
                loadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak webView] _, change in
                    guard change.newValue == false else { return }
                    if Thread.isMainThread {
                        MainActor.assumeIsolated {
                            guard let webView else { return }
                            guard let control = webView.scrollView.refreshControl, control.isRefreshing else { return }
                            // Defer past the KVO callback to avoid re-entrancy.
                            RunLoop.main.perform {
                                control.endRefreshing()
                            }
                        }
                    } else {
                        RunLoop.main.perform {
                            MainActor.assumeIsolated {
                                guard let webView else { return }
                                guard let control = webView.scrollView.refreshControl, control.isRefreshing else { return }
                                // Defer past the KVO callback to avoid re-entrancy.
                                RunLoop.main.perform {
                                    control.endRefreshing()
                                }
                            }
                        }
                    }
                }
            }
        }

        @objc private func handlePullToRefresh() {
            onPullToRefresh?()
        }

        func bindScrollObservationIfNeeded(to scrollView: UIScrollView) {
            guard boundScrollView !== scrollView else { return }
            // Tear down any previous observation before rebinding.
            scrollObservation?.invalidate()
            scrollObservation = nil
            boundScrollView = scrollView
            guard onScroll != nil else { return }
            // KVO is stable and does not fight WKWebView's internal scroll delegate.
            scrollObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] sv, _ in
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        self.latestContentOffset = sv.contentOffset
                        guard self.pendingScrollCallback == false else { return }
                        self.pendingScrollCallback = true
                        // Deliver at most once per runloop.
                        RunLoop.main.perform { [weak self, weak sv] in
                            MainActor.assumeIsolated {
                                guard let self, let sv else { return }
                                guard let onScroll = self.onScroll else {
                                    self.pendingScrollCallback = false
                                    return
                                }
                                self.pendingScrollCallback = false
                                onScroll(self.latestContentOffset, sv)
                            }
                        }
                    }
                } else {
                    RunLoop.main.perform {
                        MainActor.assumeIsolated {
                            guard let self else { return }
                            self.latestContentOffset = sv.contentOffset
                            guard self.pendingScrollCallback == false else { return }
                            self.pendingScrollCallback = true
                            // Deliver at most once per runloop.
                            RunLoop.main.perform { [weak self, weak sv] in
                                MainActor.assumeIsolated {
                                    guard let self, let sv else { return }
                                    guard let onScroll = self.onScroll else {
                                        self.pendingScrollCallback = false
                                        return
                                    }
                                    self.pendingScrollCallback = false
                                    onScroll(self.latestContentOffset, sv)
                                }
                            }
                        }
                    }
                }
            }
        }

        @MainActor
        func attachIfNeeded(
            webViewHandle: WebViewHandle,
            to container: UIView,
            onFocus: (() -> Void)?,
            forceRebind: Bool
        ) {
            self.onFocus = onFocus

            // IMPORTANT: when the handle is transiently nil, do not detach the last
            // attached WKWebView; avoid orphaning. Enter restoring mode.
            guard let webView = webViewHandle.webView else {
                scrollObservation?.invalidate()
                scrollObservation = nil
                loadingObservation?.invalidate()
                loadingObservation = nil
                boundScrollView = nil
                attachmentCoordinator.requestRestore(container: container)
                return
            }

            let outcome = attachmentCoordinator.requestAttach(
                webView: webView,
                container: container,
                identity: lastIdentity,
                forceRebind: forceRebind,
                isActivePane: isActivePane
            )

            #if DEBUG
            if outcome.didMutateHierarchy {
                debugValidateAttachment(webView: webView, container: container)
            }
            #endif

            installFocusTapIfNeeded(on: container)
            installEdgePanGesturesIfNeeded(on: container)
            // Gesture + refresh wiring must happen after attachment.
            if outcome.didMutateHierarchy || outcome.forceRewire {
                installGesturesIfNeeded(on: webView)
                bindScrollObservationIfNeeded(to: webView.scrollView)
                installPullToRefreshIfNeeded(on: webView)
            }
            // Even if no rebind/reattach occurred, layout can transition the view to a
            // reality-ready state. Check every update to avoid sticky timedOut.
            attachmentCoordinator.updateReadinessIfPossible(webView: webView, container: container, identity: lastIdentity)
        }

        #if DEBUG
        private func debugValidateAttachment(webView: WKWebView, container: UIView) {
            let identityLabel = lastIdentity.uuidString
            if webView.safariLikeWasAllocatedByWebViewPool == false {
                Diagnostics.logError(
                    "[WebViewAttach] WKWebView is not marked as WebViewPool-allocated id=\(identityLabel)",
                    subsystem: .runtime,
                    category: "WebView"
                )
            }
            func snapshot(_ webView: WKWebView?, _ container: UIView?) -> String {
                guard let webView, let container else { return "<released>" }
                let superviewOK = (webView.superview === container)
                let containerBounds = container.bounds
                let webViewFrame = webView.frame
                return "id=\(identityLabel) superOK=\(superviewOK) containerBounds=\(containerBounds) webViewFrame=\(webViewFrame) hidden=\(webView.isHidden) alpha=\(webView.alpha) window=\(webView.window != nil)"
            }
            // After the current update cycle.
            let token = attachmentCoordinator.currentToken
            Task { @MainActor [weak self, weak webView, weak container] in
                await Task.yield()
                guard let self, self.attachmentCoordinator.isTokenCurrent(token) else { return }
                guard let webView, let container else { return }
                if webView.superview !== container {
                    Diagnostics.logError(
                        "[WebViewAttach] superview mismatch (post-attach) \(snapshot(webView, container))",
                        subsystem: .runtime,
                        category: "WebView"
                    )
                    self.attachmentCoordinator.repairInvariant(webView: webView, container: container)
                }
            }
            // After 2 runloop ticks: should have non-zero bounds if container is laid out.
            Task { @MainActor [weak self, weak webView, weak container] in
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard let self, self.attachmentCoordinator.isTokenCurrent(token) else { return }
                guard let webView, let container else { return }
                if container.bounds.size == .zero {
                    Diagnostics.logDebug(
                        "[WebViewAttach] container has zero bounds (early) \(snapshot(webView, container))",
                        subsystem: .runtime,
                        category: "WebView"
                    )
                }
                if webView.bounds.size == .zero, container.bounds.size != .zero {
                    Diagnostics.logError(
                        "[WebViewAttach] webView has zero bounds (post-layout) \(snapshot(webView, container))",
                        subsystem: .runtime,
                        category: "WebView"
                    )
                }
            }
            // After a short delay: if active, we expect the web view to be in a window.
            Task { @MainActor [weak self, weak webView, weak container] in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self else { return }
                guard self.attachmentCoordinator.isTokenCurrent(token) else { return }
                guard let webView, let container else { return }
                guard (self.isActivePane?() ?? true) else { return }
                if webView.window == nil {
                    Diagnostics.logError(
                        "[WebViewAttach] active pane WKWebView not in window (1s) \(snapshot(webView, container))",
                        subsystem: .runtime,
                        category: "WebView"
                    )
                }
            }
        }
        #endif
    }
}
