import Foundation
import BrowserCore
import SafariLikeContracts
import WebKit

@MainActor
public final class WebKitPolicyBridge: NSObject, WKNavigationDelegate, WKUIDelegate {
    private weak var store: TabWebStore?
    private let tabID: UUID
    private let windowID: String

    // Loop guard for reissued main-frame navigations.
    private var lastReissueTokenByURL: [String: String] = [:]

    // Redirect safety tracking (main-frame only).
    private var redirectChain: [String] = []
    private var redirectDepth: Int = 0

    /// Best-effort snapshot used by higher layers for Safari-like navigation collapse.
    ///
    /// Note: This is not a stable WebKit API; it is a deterministic approximation.
    public var currentRedirectDepth: Int { redirectDepth }

    public init(store: TabWebStore) {
        self.store = store
        self.tabID = store.tabID
        self.windowID = store.windowID
        super.init()
    }

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow, preferences)
            return
        }

        // Safari-like policy layer (pure input -> decision).
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        let isNewWindowRequest = (navigationAction.targetFrame == nil)

        let point: NavigationDecisionPoint = {
            if isNewWindowRequest { return .newWindow }
            if isMainFrame, navigationAction.navigationType == .other, redirectChain.isEmpty == false {
                return .redirect
            }
            return .beforeNavigation
        }()

        let wasAlreadyInRedirectChain = redirectChain.contains(url.absoluteString)

        if isMainFrame {
            switch point {
            case .beforeNavigation:
                redirectChain = [url.absoluteString]
                redirectDepth = 0
            case .redirect:
                redirectDepth += 1
                if wasAlreadyInRedirectChain == false {
                    redirectChain.append(url.absoluteString)
                }
            case .afterResponse, .newWindow:
                break
            }
        }

        let policy = effectiveNavigationPolicy(for: url)

        // Apply autoplay policy best-effort (WebKit is largely per-webview, not per-request).
        // This is Safari-like behavior: the setting is evaluated per-navigation.
        if #available(iOS 10.0, *) {
            let previous = webView.configuration.mediaTypesRequiringUserActionForPlayback
            let didApply = WebViewMediaPolicy.applyAutoplayPolicy(
                to: webView.configuration,
                allowAutoplay: policy.allowAutoplay
            )
            if didApply {
                let host = url.host ?? ""
                let desired = WebViewMediaPolicy.desiredMediaTypesRequiringUserActionForPlayback(
                    allowAutoplay: policy.allowAutoplay
                )
                Diagnostics.logInfo(
                    "[WebKitPolicyBridge] fallback autoplay applied tabID=\(self.tabID.uuidString) host=\(host) allowAutoplay=\(policy.allowAutoplay) previous=\(String(describing: previous)) desired=\(String(describing: desired))",
                    subsystem: .web,
                    category: "Autoplay"
                )
            }
        }
        let input = NavigationPolicyInput(
            point: point,
            urlString: url.absoluteString,
            scheme: url.scheme?.lowercased() ?? "",
            isMainFrame: isMainFrame,
            navigationType: map(navigationAction.navigationType),
            isNewWindowRequest: isNewWindowRequest,
            redirectDepth: redirectDepth,
            isRedirectCycle: (isMainFrame && point == .redirect && wasAlreadyInRedirectChain),
            mimeType: nil
        )
        let policyDecision = SafariNavigationPolicyEvaluator.evaluate(policy: policy, input: input)
        logPolicyDecision(policyDecision, url: url)

        switch policyDecision.outcome {
        case .allow:
            break
        case .cancel:
            // If the store is not available (e.g. during teardown/transition),
            // never cancel the navigation purely due to policy evaluation.
            // Safari rule: launching/restoring must not strand the WebView.
            guard store != nil else {
                decisionHandler(.allow, preferences)
                return
            }
            decisionHandler(.cancel, preferences)
            return
        case .openInNewTab, .openInNewWindow:
            // WKWebView can't truly create a new window here. Route to app-level tab/window.
            if let store, let handler = store.onOpenInNewTabRequested {
                handler(navigationAction.request)
                decisionHandler(.cancel, preferences)
                return
            }
            // If the routing hook isn't installed yet, do not cancel the load.
            decisionHandler(.allow, preferences)
            return
        }

        // Cross-site tracking / private mode: best-effort privacy headers on main-frame.
        // Note: This is not a complete tracking prevention implementation; it is an explicit,
        // deterministic hook point for Safari-like policy.
        if isMainFrame, (policy.privateMode || policy.allowCrossSiteTracking == false) {
            let existing = navigationAction.request.allHTTPHeaderFields ?? [:]
            let needsDNT = existing["DNT"] == nil
            let needsGPC = existing["Sec-GPC"] == nil
            if needsDNT || needsGPC {
                var add: [String: String] = [:]
                if needsDNT { add["DNT"] = "1" }
                if needsGPC { add["Sec-GPC"] = "1" }
                let mutation = PolicyMutation(headersToAdd: add)
                self.applyMutation(webView: webView, request: navigationAction.request, mutation: mutation)
                decisionHandler(.cancel, preferences)
                return
            }
        }

        // Loop guard: if we already reissued this exact URL with a token, allow it.
        if let token = navigationAction.request.value(forHTTPHeaderField: "X-SLK-Policy-Reissue"),
           let expected = lastReissueTokenByURL[url.absoluteString],
           token == expected {
            lastReissueTokenByURL[url.absoluteString] = nil
            forwardToPreferencesDelegate(webView, navigationAction, preferences, decisionHandler)
            return
        }

        let ctx = NavigationContext(
            tabID: tabID,
            windowID: windowID,
            url: url,
            isMainFrame: isMainFrame,
            hasUserGesture: false,
            navigationType: map(navigationAction.navigationType),
            sourceURL: webView.url
        )

        Task { @MainActor in
            let decision = await PolicyCenter.shared.decideNavigation(ctx)
            switch decision {
            case .allow:
                self.forwardToPreferencesDelegate(webView, navigationAction, preferences, decisionHandler)
            case .cancel(let reason):
                if reason.hasPrefix("reissue://"),
                   let target = URL(string: String(reason.dropFirst("reissue://".count))) {
                    self.reissueMainFrameIfNeeded(webView: webView, original: navigationAction.request, targetURL: target)
                    decisionHandler(.cancel, preferences)
                    return
                }
                // If we can't route/record the cancellation (store not ready),
                // never cancel the underlying navigation.
                guard self.store != nil else {
                    decisionHandler(.allow, preferences)
                    return
                }
                decisionHandler(.cancel, preferences)
            case .modify(let mutation):
                if (mutation.userAgentOverride != nil || mutation.headersToAdd.isEmpty == false || mutation.headersToRemove.isEmpty == false),
                   (navigationAction.targetFrame?.isMainFrame ?? true) {
                    self.applyMutation(webView: webView, request: navigationAction.request, mutation: mutation)
                    decisionHandler(.cancel, preferences)
                    return
                }

                // For subresources, we can only apply best-effort UA.
                if let ua = mutation.userAgentOverride {
                    webView.customUserAgent = ua
                }
                self.forwardToPreferencesDelegate(webView, navigationAction, preferences, decisionHandler)
            }
        }
    }

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        guard let url = navigationResponse.response.url else {
            forwardNavigationResponse(webView, navigationResponse, decisionHandler)
            return
        }

        // Safari-like policy layer (pure input -> decision).
        let mimeType: String? = {
            if let http = navigationResponse.response as? HTTPURLResponse {
                return http.mimeType
            }
            return navigationResponse.response.mimeType
        }()

        let policy = effectiveNavigationPolicy(for: url)
        let input = NavigationPolicyInput(
            point: .afterResponse,
            urlString: url.absoluteString,
            scheme: url.scheme?.lowercased() ?? "",
            isMainFrame: navigationResponse.isForMainFrame,
            navigationType: .other,
            isNewWindowRequest: false,
            redirectDepth: redirectDepth,
            isRedirectCycle: false,
            mimeType: mimeType
        )
        let policyDecision = SafariNavigationPolicyEvaluator.evaluate(policy: policy, input: input)
        logPolicyDecision(policyDecision, url: url)

        let initiator = webView.url
        let isThirdParty = (initiator?.host?.lowercased() != url.host?.lowercased())
        let ctx = ResourceContext(
            tabID: tabID,
            windowID: windowID,
            url: url,
            resourceType: .document,
            initiator: initiator,
            isThirdParty: isThirdParty
        )

        Task { @MainActor in
            let decision = await PolicyCenter.shared.decideResource(ctx)
            switch decision {
            case .allow, .modify:
                self.forwardNavigationResponse(webView, navigationResponse, decisionHandler)
            case .cancel:
                // Safari rule: launching/restoring state must not block main document loads.
                // Policy providers may still *observe* and *log*, but cancellation here
                // can strand the WebView on a white page during launch.
                self.forwardNavigationResponse(webView, navigationResponse, decisionHandler)
            }
        }
    }

    // MARK: - WKUIDelegate privacy prompts (forward by default)

    @available(iOS 15.0, *)
    public func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let url = webView.url ?? DefaultURLs.aboutBlank

        let operation: PrivacyOperation
        switch type {
        case .camera: operation = .camera
        case .microphone: operation = .microphone
        case .cameraAndMicrophone: operation = .other
        @unknown default: operation = .other
        }

        let ctx = PrivacyContext(tabID: tabID, windowID: windowID, url: url, operation: operation, isThirdParty: false)

        Task { @MainActor in
            let decision = await PolicyCenter.shared.decidePrivacy(ctx)
            switch decision {
            case .cancel:
                decisionHandler(.deny)
            default:
                guard let store = self.store else {
                    Diagnostics.logDebug(
                        "[WebKitPolicyBridge] store nil before media capture decision; defaulting to deny (tabID=\(self.tabID.uuidString))",
                        subsystem: .web,
                        category: "Policy"
                    )
                    decisionHandler(.deny)
                    return
                }
                store.webView(webView, requestMediaCapturePermissionFor: origin, initiatedByFrame: frame, type: type, decisionHandler: decisionHandler)
            }
        }
    }

    @available(iOS 15.0, *)
    public func webView(
        _ webView: WKWebView,
        requestGeolocationPermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let url = webView.url ?? DefaultURLs.aboutBlank
        let ctx = PrivacyContext(tabID: tabID, windowID: windowID, url: url, operation: .geolocation, isThirdParty: false)

        Task { @MainActor in
            let decision = await PolicyCenter.shared.decidePrivacy(ctx)
            switch decision {
            case .cancel:
                decisionHandler(.deny)
            default:
                guard let store = self.store else {
                    Diagnostics.logDebug(
                        "[WebKitPolicyBridge] store nil before geolocation decision; defaulting to deny (tabID=\(self.tabID.uuidString))",
                        subsystem: .web,
                        category: "Policy"
                    )
                    decisionHandler(.deny)
                    return
                }
                store.webView(webView, requestGeolocationPermissionFor: origin, initiatedByFrame: frame, decisionHandler: decisionHandler)
            }
        }
    }

    // MARK: - Helpers

    private func forwardToPreferencesDelegate(
        _ webView: WKWebView,
        _ action: WKNavigationAction,
        _ preferences: WKWebpagePreferences,
        _ decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        guard let store else {
            Diagnostics.logDebug(
                "[WebKitPolicyBridge] store nil before navigation policy decision; allowing (tabID=\(tabID.uuidString))",
                subsystem: .web,
                category: "Policy"
            )
            decisionHandler(.allow, preferences)
            return
        }
        store.webView(webView, decidePolicyFor: action, preferences: preferences, decisionHandler: decisionHandler)
    }

    private func forwardNavigationResponse(
        _ webView: WKWebView,
        _ response: WKNavigationResponse,
        _ decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        guard let store else {
            Diagnostics.logDebug(
                "[WebKitPolicyBridge] store nil before navigation response decision; allowing (tabID=\(tabID.uuidString))",
                subsystem: .web,
                category: "Policy"
            )
            decisionHandler(.allow)
            return
        }
        store.webView(webView, decidePolicyFor: response, decisionHandler: decisionHandler)
    }

    private func applyMutation(webView: WKWebView, request: URLRequest, mutation: PolicyMutation) {
        var rebuilt = request
        var headers = rebuilt.allHTTPHeaderFields ?? [:]
        for key in mutation.headersToRemove { headers.removeValue(forKey: key) }
        for (k, v) in mutation.headersToAdd { headers[k] = v }

        let urlKey = rebuilt.url?.absoluteString ?? ""
        let token = UUID().uuidString
        lastReissueTokenByURL[urlKey] = token
        headers["X-SLK-Policy-Reissue"] = token
        rebuilt.allHTTPHeaderFields = headers

        if let ua = mutation.userAgentOverride {
            webView.customUserAgent = ua
        }

        webView.load(rebuilt)
    }

    private func reissueMainFrameIfNeeded(webView: WKWebView, original: URLRequest, targetURL: URL) {
        var rebuilt = original
        rebuilt.url = targetURL
        webView.load(rebuilt)
    }

    private func effectiveNavigationPolicy(for url: URL) -> NavigationPolicy {
        guard let store else {
            return NavigationPolicy(
                allowPopups: false,
                allowAutoplay: false,
                allowCrossSiteTracking: false,
                contentBlockerEnabled: true,
                privateMode: false
            )
        }

        let host = url.host ?? ""
        let prefs = (!host.isEmpty ? store.websitePreferencesProvider?.getPreferences(for: host) : nil)

        let allowPopups = (prefs?.allowsPopups ?? false) && (prefs?.allowsWindowOpen ?? true)
        let allowAutoplay = (prefs?.allowsMediaAutoplay ?? false) || (prefs?.allowsAudioAutoplay ?? false)
        let allowCrossSiteTracking = !(prefs?.blockCookies ?? false)
        let contentBlockerEnabled = (prefs?.contentBlockerEnabled ?? true)
        let privateMode = (store.browsingProfile == .private)

        return NavigationPolicy(
            allowPopups: allowPopups,
            allowAutoplay: allowAutoplay,
            allowCrossSiteTracking: allowCrossSiteTracking,
            contentBlockerEnabled: contentBlockerEnabled,
            privateMode: privateMode
        )
    }

    private func logPolicyDecision(_ decision: NavigationPolicyDecision, url: URL) {
        guard DiagnosticsGate.isEnabled else { return }
        guard let store else { return }

        let details: String? = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.withoutEscapingSlashes]
            if let data = try? encoder.encode(decision) {
                return String(data: data, encoding: .utf8)
            }
            return nil
        }()

        let event = SessionJournalEvent(
            type: .policyDecision,
            windowID: store.windowID,
            paneID: store.paneID,
            tabID: store.tabID,
            url: url.absoluteString,
            details: details
        )

        store.onPolicyDecisionEvent?(event)
    }

    private func map(_ t: WKNavigationType) -> NavigationType {
        switch t {
        case .linkActivated: return .link
        case .formSubmitted, .formResubmitted: return .formSubmit
        case .backForward: return .backForward
        case .reload: return .reload
        case .other: return .other
        @unknown default: return .other
        }
    }
}
