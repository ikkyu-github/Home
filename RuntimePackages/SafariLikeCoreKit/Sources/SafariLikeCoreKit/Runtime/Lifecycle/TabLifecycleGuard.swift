import Foundation
import os
import WebKit

/// Safari-grade lifecycle invariant guardrails.
///
/// Goals:
/// - Catch cross-window/pane ownership bugs early (DEBUG assertion).
/// - In RELEASE: log once and suppress side effects rather than crashing.
/// - Keep CoreKit UI-free (no UIKit/SwiftUI imports).
@MainActor
public enum TabLifecycleGuard {
    private static let logger = Logger(subsystem: "SafariLikeCoreKit", category: "TabLifecycleGuard")

    public enum Violation: String, Sendable {
        case activationWhileInvalidated
        case activationWithInconsistentWebViewState
        case activationWithMismatchedWindowID
        case activationWithMismatchedPaneID
        case activationWithSharedWebContextServices
        case activationCreatedUntrackedWebView
        case attachmentMissingHandle
        case attachmentMissingWebView
        case attachmentUntrackedWebView
        case attachmentMismatchedWindowID
    }

    private struct OnceKey: Hashable {
        let violation: Violation
        let windowID: String
        let paneID: String
        let tabID: UUID
    }

    private static var loggedOnce: Set<OnceKey> = []

    private static func reportOnce(
        _ violation: Violation,
        store: TabWebStore,
        message: String
    ) {
        let key = OnceKey(violation: violation, windowID: store.windowID, paneID: store.paneID, tabID: store.tabID)
        if loggedOnce.contains(key) { return }
        loggedOnce.insert(key)
        logger.error("\(message, privacy: .public)")
        Diagnostics.logError(message, subsystem: .runtime, category: "TabLifecycle")
    }

    private static func debugAssert(_ message: String) {
        #if DEBUG
        assertionFailure(message)
        #endif
    }

    /// Validates invariants before attempting to activate a store.
    ///
    /// Returns `true` if activation may proceed.
    public static func validateBeforeActivation(
        store: TabWebStore,
        expectedWindowID: String,
        requestedPaneID: String
    ) -> Bool {
        if store.isInvalidated {
            let msg = "[TabLifecycle] SUPPRESS activation: store invalidated tabID=\(store.tabID) windowID=\(store.windowID) paneID=\(store.paneID)"
            debugAssert(msg)
            reportOnce(.activationWhileInvalidated, store: store, message: msg)
            return false
        }

        // WebView + handle are treated as a single unit: either both exist or neither exists.
        let hasWebView = (store.webView != nil)
        let hasHandle = (store.webViewHandle != nil)
        if hasWebView != hasHandle {
            let msg = "[TabLifecycle] SUPPRESS activation: inconsistent state (webView=\(hasWebView) handle=\(hasHandle)) tabID=\(store.tabID) windowID=\(store.windowID) paneID=\(store.paneID)"
            debugAssert(msg)
            reportOnce(.activationWithInconsistentWebViewState, store: store, message: msg)
            return false
        }

        if store.windowID != expectedWindowID {
            let msg = "[TabLifecycle] SUPPRESS activation: windowID mismatch expected=\(expectedWindowID) actual=\(store.windowID) tabID=\(store.tabID) paneID=\(store.paneID)"
            debugAssert(msg)
            reportOnce(.activationWithMismatchedWindowID, store: store, message: msg)
            return false
        }

        // PaneID mismatches are extremely risky: WebContext routing + keying is pane-aware.
        if store.paneID != requestedPaneID {
            let msg = "[TabLifecycle] SUPPRESS activation: paneID mismatch requested=\(requestedPaneID) store=\(store.paneID) tabID=\(store.tabID) windowID=\(store.windowID)"
            debugAssert(msg)
            reportOnce(.activationWithMismatchedPaneID, store: store, message: msg)
            return false
        }

        return true
    }

    /// Validates invariants after activation.
    public static func validateAfterActivation(store: TabWebStore) {
        guard let webView = store.webView else {
            let msg = "[TabLifecycle] activation postcondition failed: webView is nil tabID=\(store.tabID) windowID=\(store.windowID) paneID=\(store.paneID)"
            debugAssert(msg)
            reportOnce(.activationCreatedUntrackedWebView, store: store, message: msg)
            return
        }
        if webView.safariLikeWasAllocatedByWebViewPool == false {
            let msg = "[TabLifecycle] activation produced untracked WKWebView [not pool-allocated] tabID=\(store.tabID) windowID=\(store.windowID) paneID=\(store.paneID)"
            debugAssert(msg)
            reportOnce(.activationCreatedUntrackedWebView, store: store, message: msg)
        }
    }

    /// Validates invariants when UI reports a WebView attach event.
    ///
    /// Returns `true` if the attachment event matches runtime reality.
    public static func validateAttachmentEvent(store: TabWebStore, expectedWindowID: String) -> Bool {
        if store.windowID != expectedWindowID {
            let msg = "[TabLifecycle] attachment windowID mismatch expected=\(expectedWindowID) actual=\(store.windowID) tabID=\(store.tabID) paneID=\(store.paneID)"
            debugAssert(msg)
            reportOnce(.attachmentMismatchedWindowID, store: store, message: msg)
            return false
        }

        guard let handle = store.webViewHandle else {
            let msg = "[TabLifecycle] attachment event but store has no WebViewHandle tabID=\(store.tabID) windowID=\(store.windowID) paneID=\(store.paneID)"
            debugAssert(msg)
            reportOnce(.attachmentMissingHandle, store: store, message: msg)
            return false
        }

        guard let webView = handle.webView else {
            let msg = "[TabLifecycle] attachment event but handle.webView is nil tabID=\(store.tabID) windowID=\(store.windowID) paneID=\(store.paneID)"
            debugAssert(msg)
            reportOnce(.attachmentMissingWebView, store: store, message: msg)
            return false
        }

        if webView.safariLikeWasAllocatedByWebViewPool == false {
            let msg = "[TabLifecycle] attachment using untracked WKWebView [not pool-allocated] tabID=\(store.tabID) windowID=\(store.windowID) paneID=\(store.paneID)"
            debugAssert(msg)
            reportOnce(.attachmentUntrackedWebView, store: store, message: msg)
            return false
        }

        return true
    }
}
