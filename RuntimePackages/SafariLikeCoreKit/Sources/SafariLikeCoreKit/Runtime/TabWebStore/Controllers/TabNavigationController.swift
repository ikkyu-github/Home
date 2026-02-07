import Foundation
import WebKit
import os
import BrowserCore
import SafariLikeContracts

@MainActor
public protocol TabNavigationControlling: AnyObject {
	func goBack()
	func goForward()
	func reload()
	func stopLoading()
	func load(_ url: URL, force: Bool)
	func load(_ request: URLRequest, force: Bool)
	func load(_ urlString: String, force: Bool)
	func setBypassSmartSplitOnce()
	func loadSearch(query: String)

	func performLoadResolvedURL(_ urlString: String)
	func attemptPerformPendingLoad(reason: String)

	func handleWebPermissionPromptResponse(_ response: WebPermissionPromptResponse)

	func webView(
		_ webView: WKWebView,
		decidePolicyFor navigationAction: WKNavigationAction,
		preferences: WKWebpagePreferences,
		decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
	)

	func webView(
		_ webView: WKWebView,
		decidePolicyFor navigationResponse: WKNavigationResponse,
		decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
	)

	func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!)
	func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!)
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error)
	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error)
	func webViewWebContentProcessDidTerminate(_ webView: WKWebView)

	@available(iOS 14.5, macOS 11.3, *)
	func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload)

	@available(iOS 14.5, macOS 11.3, *)
	func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload)

	@available(iOS 14.5, macOS 11.3, *)
	func download(
		_ download: WKDownload,
		decideDestinationUsing response: URLResponse,
		suggestedFilename: String,
		completionHandler: @escaping @MainActor @Sendable (URL?) -> Void
	)

	@available(iOS 14.5, macOS 11.3, *)
	func downloadDidFinish(_ download: WKDownload)

	@available(iOS 14.5, macOS 11.3, *)
	func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?)

	func webView(
		_ webView: WKWebView,
		requestMediaCapturePermissionFor origin: WKSecurityOrigin,
		initiatedByFrame frame: WKFrameInfo,
		type: WKMediaCaptureType,
		decisionHandler: @escaping (WKPermissionDecision) -> Void
	)

	func webView(
		_ webView: WKWebView,
		requestGeolocationPermissionFor origin: WKSecurityOrigin,
		initiatedByFrame frame: WKFrameInfo,
		decisionHandler: @escaping (WKPermissionDecision) -> Void
	)

	func configureWebViewAfterInit(defaultHomeURLString: String)
	func resetForReuse(defaultHomeURLString: String)
	func invalidateWebViewCore()
}

@MainActor
public final class TabNavigationController: NSObject, TabNavigationControlling {
	private unowned let store: TabWebStore

	private static let desktopUserAgent: String =
		"Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) " +
		"AppleWebKit/605.1.15 (KHTML, like Gecko) " +
		"Version/17.0 Mobile/15E148 Safari/604.1"

	public init(store: TabWebStore) {
		self.store = store
		super.init()
	}

	// MARK: - WebNavigator-like API

	public func goBack() {
		guard !store.isInvalidated, let handle = store.webViewHandle, handle.isAlive else { return }
		handle.goBack()
	}

	public func goForward() {
		guard !store.isInvalidated, let handle = store.webViewHandle, handle.isAlive else { return }
		handle.goForward()
	}

	public func reload() {
		guard !store.isInvalidated, let handle = store.webViewHandle, handle.isAlive else { return }
		handle.reload()
	}

	public func stopLoading() {
		guard !store.isInvalidated, let handle = store.webViewHandle, handle.isAlive else { return }
		handle.stopLoading()
	}

	public func load(_ url: URL, force: Bool) {
		guard !store.isInvalidated, let handle = store.webViewHandle, handle.isAlive else { return }
		if force { setBypassSmartSplitOnce() }
		handle.load(url: url)
	}

	public func load(_ request: URLRequest, force: Bool) {
		guard !store.isInvalidated, let handle = store.webViewHandle, handle.isAlive else { return }
		if force { setBypassSmartSplitOnce() }
		handle.load(request: request)
	}

	// MARK: - URL normalization / policy validation

	public func load(_ urlString: String, force: Bool) {
		guard !store.isInvalidated else { return }
		let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			store.logger.debug("TabWebStore load ignored: empty urlString")
			return
		}

		guard let resolved = OmniboxParser.resolve(trimmed, searchEngineTemplateURL: store.searchEngineURL) else {
			store.logger.debug("TabWebStore load ignored: failed to resolve input=\(trimmed, privacy: .public)")
			return
		}

		let forceInt = force ? 1 : 0
		store.logger.debug(
			"TabWebStore load input=\(trimmed, privacy: .public) resolved=\(resolved.resolvedURLString, privacy: .public) kind=\(String(describing: resolved.kind), privacy: .public) force=\(forceInt)"
		)
		if force { store.bypassSmartSplitOnce = false }
		performLoadResolvedURL(resolved.resolvedURLString)
	}

	public func setBypassSmartSplitOnce() {
		store.bypassSmartSplitOnce = true
	}

	public func loadSearch(query: String) {
		guard let resolved = OmniboxParser.resolve(query, searchEngineTemplateURL: store.searchEngineURL) else { return }
		store.logger.debug("TabWebStore loadSearch query=\(query, privacy: .public) resolved=\(resolved.resolvedURLString, privacy: .public)")
		performLoadResolvedURL(resolved.resolvedURLString)
	}

	// MARK: - WebView core wiring

	public func configureWebViewAfterInit(defaultHomeURLString: String) {
		guard !store.isInvalidated,
			  let handle = store.webViewHandle,
			  handle.isAlive,
			  let webView = handle.webView
		else { return }

		let ucc = webView.configuration.userContentController

		// User agent is applied per-navigation based on per-site preferences.
		webView.customUserAgent = nil

		store.contentBlockingController.applyContentBlocking()

		// Safe cleanup: remove only our known handlers (do not remove all user scripts).
		ucc.removeScriptMessageHandler(forName: "webInputFocused")
		ucc.removeScriptMessageHandler(forName: "slkDOMInteractive")

		store.installUserScriptsAndMessageHandlers(into: ucc)

		let bridge = WebKitPolicyBridge(store: store)
		store.policyBridge = bridge
		handle.setNavigationDelegate(bridge)
		handle.setUIDelegate(bridge)

		bindWebView()

		// If navigation was requested before the WebView was ready, perform it now.
		attemptPerformPendingLoad(reason: "configureWebViewAfterInit")
	}

	public func resetForReuse(defaultHomeURLString: String) {
		guard !store.isInvalidated, let handle = store.webViewHandle, handle.isAlive else { return }

		// 1) Reset internal async work and navigation state.
		store.resetForReuseInternal(defaultHomeURLString: defaultHomeURLString)

		// 2) Detach observers, delegates, and scripts from the WebView.
		invalidateWebViewCore()

		// 3) Reconfigure WebView bindings and default content.
		configureWebViewAfterInit(defaultHomeURLString: defaultHomeURLString)
	}

	private func bindWebView() {
		clearWebViewBindings()

		guard !store.isInvalidated,
			  let handle = store.webViewHandle,
			  handle.isAlive,
			  let webView = handle.webView
		else { return }

		store.titleObservation = webView.observe(\.title, options: [.initial, .new]) { [weak store] webView, _ in
			let newTitle = webView.title ?? ""
			Task { @MainActor [weak store] in
				store?.updatePageTitle(newTitle)
			}
		}

		store.urlObservation = webView.observe(\.url, options: [.initial, .new]) { [weak store] webView, _ in
			let newURL = webView.url
			Task { @MainActor [weak store] in
				store?.updateCurrentURL(newURL)
			}
		}

		store.canGoBackObservation = webView.observe(\.canGoBack, options: [.initial, .new]) { [weak store] webView, _ in
			let value = webView.canGoBack
			Task { @MainActor [weak store] in
				store?.updateCanGoBack(value)
			}
		}

		store.canGoForwardObservation = webView.observe(\.canGoForward, options: [.initial, .new]) { [weak store] webView, _ in
			let value = webView.canGoForward
			Task { @MainActor [weak store] in
				store?.updateCanGoForward(value)
			}
		}

		store.estimatedProgressObservation = webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak store] webView, _ in
			let progress = webView.estimatedProgress
			Task { @MainActor [weak store] in
				store?.updateEstimatedProgress(progress)
			}
		}

		store.isLoadingObservation = webView.observe(\.isLoading, options: [.initial, .new]) { [weak store] webView, _ in
			let loading = webView.isLoading
			Task { @MainActor [weak store] in
				store?.updateIsLoading(loading)
			}
		}
	}

	private func clearWebViewBindings() {
		store.titleObservation?.invalidate()
		store.titleObservation = nil

		store.urlObservation?.invalidate()
		store.urlObservation = nil

		store.canGoBackObservation?.invalidate()
		store.canGoBackObservation = nil

		store.canGoForwardObservation?.invalidate()
		store.canGoForwardObservation = nil

		store.estimatedProgressObservation?.invalidate()
		store.estimatedProgressObservation = nil

		store.isLoadingObservation?.invalidate()
		store.isLoadingObservation = nil
	}

	// MARK: - Pending load helpers

	public func performLoadResolvedURL(_ urlString: String) {
		guard !store.isInvalidated else { return }
		store.pendingResolvedURLString = urlString
		attemptPerformPendingLoad(reason: "performLoadResolvedURL")
	}

	public func attemptPerformPendingLoad(reason: String) {
		guard !store.isInvalidated else { return }
		guard let pending = store.pendingResolvedURLString else { return }
		guard let url = URL(string: pending) else {
			store.logger.debug("TabWebStore pending load dropped: invalid URL=\(pending, privacy: .public) reason=\(reason, privacy: .public)")
			store.pendingResolvedURLString = nil
			return
		}

		guard let handle = store.webViewHandle, handle.isAlive, let webView = handle.webView else {
			store.logger.debug("TabWebStore pending load deferred: url=\(pending, privacy: .public) reason=\(reason, privacy: .public)")
			return
		}

		// Apply per-site preferences to the web view configuration before loading.
		if let host = url.host, !host.isEmpty, let applier = store.websitePreferencesProvider as? WebsitePreferencesApplying {
			applier.applyPreferences(to: webView.configuration, forHost: host)
		}

		store.pendingResolvedURLString = nil
		if store.userScriptStore == nil {
			store.logger.debug("TabWebStore load executing: url=\(url.absoluteString, privacy: .public) reason=\(reason, privacy: .public)")
			handle.load(url: url)
			return
		}

		// Apply user scripts for this navigation before load (required for documentStart).
		Task { @MainActor [weak store, weak webView, weak handle] in
			guard let store, let webView, let handle, handle.isAlive else { return }
			await store.applyUserScriptsIfNeeded(for: url, in: webView)
			store.logger.debug("TabWebStore load executing: url=\(url.absoluteString, privacy: .public) reason=\(reason, privacy: .public)")
			handle.load(url: url)
		}
	}

	public func invalidateWebViewCore() {
		// 1️⃣ Cancel all KVO bindings before touching the webView or delegates.
		clearWebViewBindings()

		guard let handle = store.webViewHandle, handle.isAlive else { return }

		// 2️⃣ Detach WKWebView delegates to prevent further callbacks into this instance.
		handle.setNavigationDelegate(nil)
		handle.setUIDelegate(nil)

		store.policyBridge = nil

		// 3️⃣ Remove script handlers and user scripts to stop JavaScript → native callbacks.
		handle.withUserContentController { controller in
			controller.removeAllUserScripts()
			controller.removeScriptMessageHandler(forName: "webInputFocused")
			controller.removeScriptMessageHandler(forName: "slkDOMInteractive")
			controller.removeScriptMessageHandler(forName: "slkLoginFormDetected")
			controller.removeScriptMessageHandler(forName: "slkSignupFormDetected")
			controller.removeScriptMessageHandler(forName: "bridge")
			controller.removeScriptMessageHandler(forName: "callback")
			controller.removeScriptMessageHandler(forName: "event")
		}

		// 4️⃣ Finally, stop any in-flight loads.
		handle.stopLoading()
	}

	// MARK: - WKNavigationDelegate forwarding

	@available(iOS 13.0, *)
	public func webView(
		_ webView: WKWebView,
		decidePolicyFor navigationAction: WKNavigationAction,
		preferences: WKWebpagePreferences,
		decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
	) {
		let host = navigationAction.request.url?.host ?? webView.url?.host

		if let host, !host.isEmpty, let provider = store.websitePreferencesProvider {
			let prefs = provider.getPreferences(for: host)

			preferences.allowsContentJavaScript = prefs.javaScriptEnabled

			let desiredUserAgent: String?
			switch prefs.userAgent {
			case .desktop:
				desiredUserAgent = Self.desktopUserAgent
			case .mobile:
				desiredUserAgent = nil
			@unknown default:
				desiredUserAgent = nil
			}
			if webView.customUserAgent != desiredUserAgent {
				webView.customUserAgent = desiredUserAgent
			}

			if prefs.contentBlockerEnabled == false {
				webView.configuration.userContentController.removeAllContentRuleLists()
			}
		}

		decisionHandler(.allow, preferences)
	}

	public func webView(
		_ webView: WKWebView,
		decidePolicyFor navigationResponse: WKNavigationResponse,
		decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
	) {
		guard !store.isInvalidated else {
			decisionHandler(.cancel)
			return
		}

		let response = navigationResponse.response
		guard let url = response.url else {
			decisionHandler(.allow)
			return
		}

		var isAttachment = false
		if let http = response as? HTTPURLResponse,
		   let cd = http.value(forHTTPHeaderField: "Content-Disposition")?.lowercased() {
			isAttachment = cd.contains("attachment")
		}

		if navigationResponse.canShowMIMEType == false || isAttachment {
			let request = URLRequest(url: url)
			store.onDownloadRequested?(request, response)
			decisionHandler(.cancel)
			return
		}

		decisionHandler(.allow)
	}

	public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		store.isLoading = true
		store.navigationStartAt = Date()
	}

	public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
		store.uxRestoreController.markCompleted()
		store.webViewHandle?.updateLastKnownURL(webView.url)
		if let url = webView.url ?? store.webViewHandle?.lastKnownURL {
			store.onNavigationCommitted?(url)
		}

		if let startedAt = store.navigationStartAt {
			let elapsedMs = max(0, Date().timeIntervalSince(startedAt) * 1000)
			if let url = webView.url {
				let siteKey = SiteHeuristicsModel.normalizeSiteKey(from: url)
				Task {
					await SiteHeuristicsRuntime.collector.recordNavigation(siteKey: siteKey, loadTimeMs: elapsedMs)
				}
			}
		}
	}

	public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		store.isLoading = false
		store.webViewHandle?.updateLastKnownURL(webView.url)

		store.onPageDidFinish?(webView.url, store.pageTitle)
		store.publishCompanionItemsIfNeeded()
		store.uxRestoreController.markCompleted()

		webView.evaluateJavaScript("document.readyState") { [weak store] value, _ in
			guard let store else { return }
			let state = (value as? String) ?? ""
			if state == "interactive" || state == "complete" {
				EngineController.shared.notifyWebViewInteractive(tabID: store.tabID)
			}
		}

		normalizeScrollIfNeeded(webView)
		applySnapshotAutoFixAfterDidFinish(webView)
	}

	private func normalizeScrollIfNeeded(_ webView: WKWebView) {
		#if os(iOS)
		let scroll = webView.scrollView
		let maxY = max(0, scroll.contentSize.height - scroll.bounds.height)
		if scroll.contentOffset.y > maxY {
			scroll.setContentOffset(CGPoint(x: 0, y: maxY), animated: false)
		}
		#else
		_ = webView
		#endif
	}

	private func applySnapshotAutoFixAfterDidFinish(_ webView: WKWebView) {
		webView.takeSnapshot(with: nil) { image, _ in
			if image == nil {
				#if os(iOS)
				webView.setNeedsLayout()
				webView.layoutIfNeeded()
				webView.scrollView.setContentOffset(.zero, animated: false)
				#endif
				return
			}

			#if os(iOS)
			if webView.scrollView.contentSize.height > 0 {
				webView.layer.setNeedsDisplay()
				webView.scrollView.layer.setNeedsDisplay()
			}
			#endif
		}
	}

	public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		store.isLoading = false
		let record = NavigationErrorMapper.makeFailureRecord(
			url: webView.url,
			isMainFrame: true,
			phase: .committed,
			error: error
		)
		store.onNavigationFailure?(record)
	}

	public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		store.isLoading = false
		let record = NavigationErrorMapper.makeFailureRecord(
			url: webView.url,
			isMainFrame: true,
			phase: .provisional,
			error: error
		)
		store.onNavigationFailure?(record)
	}

	public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
		guard !store.isInvalidated else { return }
		let record = NavigationFailureRecord(
			phase: .unknown,
			isMainFrame: true,
			urlScheme: webView.url?.scheme,
			urlHost: webView.url?.host,
			category: .webContentProcessTerminated,
			errorDomain: WKError.errorDomain,
			errorCode: WKError.Code.webContentProcessTerminated.rawValue,
			message: "Web content process terminated"
		)
		store.onNavigationFailure?(record)
		EngineController.shared.notifyWebContentProcessDidTerminate(tabID: store.tabID)
		store.processRecoveryController.scheduleProcessRecoverIfNeeded()
	}

	// MARK: - WKUIDelegate forwarding (permissions)

	private func ensureWebPermissionPromptObserverInstalled() {
		guard store.webPermissionPromptObserver == nil else { return }
		store.webPermissionPromptObserver = NotificationCenter.default.addObserver(
			forName: .webPermissionPromptResponded,
			object: nil,
			queue: .main
		) { [weak store] note in
			guard let response = note.object as? WebPermissionPromptResponse else { return }
			Task { @MainActor [weak store] in
				store?.navigationController.handleWebPermissionPromptResponse(response)
			}
		}
	}

	public func handleWebPermissionPromptResponse(_ response: WebPermissionPromptResponse) {
		guard !store.isInvalidated else { return }
		guard let handler = store.pendingWebPermissionDecisions.removeValue(forKey: response.id) else { return }
		let request = store.pendingWebPermissionRequests.removeValue(forKey: response.id)
		switch response.decision {
		case .allow:
			handler(.grant)
			persistPermissionDecisionIfNeeded(request: request, decision: .allow)
		case .deny:
			handler(.deny)
			persistPermissionDecisionIfNeeded(request: request, decision: .deny)
		@unknown default:
			handler(.deny)
		}
	}

	private func persistPermissionDecisionIfNeeded(request: (host: String, kind: WebPermissionKind)?, decision: PermissionDecision) {
		guard let request else { return }
		guard store.browsingProfile == .regular else { return }
		guard let siteSettingsStore = store.siteSettingsStore else { return }
		let host = request.host
		guard host.isEmpty == false else { return }
		let siteKey = SiteKey(host: host)

		Task {
			switch request.kind {
			case .camera:
				await siteSettingsStore.setDecision(decision, for: siteKey, type: PermissionType.camera)
			case .microphone:
				await siteSettingsStore.setDecision(decision, for: siteKey, type: PermissionType.microphone)
			case .location:
				await siteSettingsStore.setDecision(decision, for: siteKey, type: PermissionType.location)
			case .cameraAndMicrophone:
				await siteSettingsStore.setDecision(decision, for: siteKey, type: PermissionType.camera)
				await siteSettingsStore.setDecision(decision, for: siteKey, type: PermissionType.microphone)
			}
		}
	}

	private func requestConfirmation(
		for host: String,
		kind: WebPermissionKind,
		decisionHandler: @escaping (WKPermissionDecision) -> Void
	) {
		ensureWebPermissionPromptObserverInstalled()
		let request = WebPermissionPromptRequest(host: host, kind: kind)
		store.pendingWebPermissionDecisions[request.id] = decisionHandler
		store.pendingWebPermissionRequests[request.id] = (host: host, kind: kind)
		NotificationCenter.default.post(name: .webPermissionPromptRequested, object: request)
	}

	@available(iOS 15.0, *)
	public func webView(
		_ webView: WKWebView,
		requestMediaCapturePermissionFor origin: WKSecurityOrigin,
		initiatedByFrame frame: WKFrameInfo,
		type: WKMediaCaptureType,
		decisionHandler: @escaping (WKPermissionDecision) -> Void
	) {
		let host = (!origin.host.isEmpty ? origin.host : (webView.url?.host ?? ""))
		guard host.isEmpty == false else {
			decisionHandler(.prompt)
			return
		}

		let kind: WebPermissionKind
		switch type {
		case .camera:
			kind = .camera
		case .microphone:
			kind = .microphone
		case .cameraAndMicrophone:
			kind = .cameraAndMicrophone
		@unknown default:
			kind = .cameraAndMicrophone
		}

		// Privacy invariant: never auto-grant persisted permissions in private browsing.
		guard store.browsingProfile == .regular else {
			requestConfirmation(for: host, kind: kind, decisionHandler: decisionHandler)
			return
		}

		if let siteSettingsStore = store.siteSettingsStore {
			let siteKey = SiteKey(host: host)
			Task {
				switch kind {
				case .camera:
					let decision = await siteSettingsStore.effectiveDecision(for: siteKey, type: PermissionType.camera)
					if decision == .ask,
						let provider = self.store.websitePreferencesProvider {
						let legacy = mapLegacyPermission(provider.getPreferences(for: host).cameraPermission)
						if legacy != .ask {
							await siteSettingsStore.setDecision(legacy, for: siteKey, type: PermissionType.camera, source: .migrated)
							handlePermissionDecision(legacy, host: host, kind: kind, decisionHandler: decisionHandler)
							return
						}
					}
					handlePermissionDecision(decision, host: host, kind: kind, decisionHandler: decisionHandler)
				case .microphone:
					let decision = await siteSettingsStore.effectiveDecision(for: siteKey, type: PermissionType.microphone)
					if decision == .ask,
						let provider = self.store.websitePreferencesProvider {
						let legacy = mapLegacyPermission(provider.getPreferences(for: host).microphonePermission)
						if legacy != .ask {
							await siteSettingsStore.setDecision(legacy, for: siteKey, type: PermissionType.microphone, source: .migrated)
							handlePermissionDecision(legacy, host: host, kind: kind, decisionHandler: decisionHandler)
							return
						}
					}
					handlePermissionDecision(decision, host: host, kind: kind, decisionHandler: decisionHandler)
				case .location:
					let decision = await siteSettingsStore.effectiveDecision(for: siteKey, type: PermissionType.location)
					if decision == .ask,
						let provider = self.store.websitePreferencesProvider {
						let legacy = mapLegacyPermission(provider.getPreferences(for: host).locationPermission)
						if legacy != .ask {
							await siteSettingsStore.setDecision(legacy, for: siteKey, type: PermissionType.location, source: .migrated)
							handlePermissionDecision(legacy, host: host, kind: kind, decisionHandler: decisionHandler)
							return
						}
					}
					handlePermissionDecision(decision, host: host, kind: kind, decisionHandler: decisionHandler)
				case .cameraAndMicrophone:
					async let cam = siteSettingsStore.effectiveDecision(for: siteKey, type: PermissionType.camera)
					async let mic = siteSettingsStore.effectiveDecision(for: siteKey, type: PermissionType.microphone)
					let camDecision = await cam
					let micDecision = await mic
					let combined: PermissionDecision
					if camDecision == .deny || micDecision == .deny {
						combined = .deny
					} else if camDecision == .allow && micDecision == .allow {
						combined = .allow
					} else {
						combined = .ask
					}
					if combined == .ask,
						let provider = self.store.websitePreferencesProvider {
						let prefs = provider.getPreferences(for: host)
						let legacyCam = mapLegacyPermission(prefs.cameraPermission)
						let legacyMic = mapLegacyPermission(prefs.microphonePermission)
						let legacyCombined: PermissionDecision
						if legacyCam == .deny || legacyMic == .deny {
							legacyCombined = .deny
						} else if legacyCam == .allow && legacyMic == .allow {
							legacyCombined = .allow
						} else {
							legacyCombined = .ask
						}
						if legacyCombined != .ask {
							await siteSettingsStore.setDecision(legacyCam, for: siteKey, type: PermissionType.camera, source: .migrated)
							await siteSettingsStore.setDecision(legacyMic, for: siteKey, type: PermissionType.microphone, source: .migrated)
							handlePermissionDecision(legacyCombined, host: host, kind: kind, decisionHandler: decisionHandler)
							return
						}
					}
					handlePermissionDecision(combined, host: host, kind: kind, decisionHandler: decisionHandler)
				}
			}
			return
		}

		// Legacy fallback: consult WebsitePreferencesProviding.
		guard let provider = store.websitePreferencesProvider else {
			decisionHandler(.prompt)
			return
		}

		let prefs = provider.getPreferences(for: host)
		let setting: WebsitePreferences.PermissionSetting
		switch type {
		case .camera:
			setting = prefs.cameraPermission
		case .microphone:
			setting = prefs.microphonePermission
		case .cameraAndMicrophone:
			if prefs.cameraPermission == .deny || prefs.microphonePermission == .deny {
				setting = .deny
			} else if prefs.cameraPermission == .allow && prefs.microphonePermission == .allow {
				setting = .allow
			} else {
				setting = .ask
			}
		@unknown default:
			setting = .ask
		}

		switch setting {
		case .allow:
			decisionHandler(.grant)
		case .deny:
			decisionHandler(.deny)
		case .ask:
			requestConfirmation(for: host, kind: kind, decisionHandler: decisionHandler)
		@unknown default:
			decisionHandler(.prompt)
		}
	}

	@available(iOS 15.0, *)
	public func webView(
		_ webView: WKWebView,
		requestGeolocationPermissionFor origin: WKSecurityOrigin,
		initiatedByFrame frame: WKFrameInfo,
		decisionHandler: @escaping (WKPermissionDecision) -> Void
	) {
		let host = (!origin.host.isEmpty ? origin.host : (webView.url?.host ?? ""))
		guard host.isEmpty == false else {
			decisionHandler(.prompt)
			return
		}

		// Privacy invariant: never auto-grant persisted permissions in private browsing.
		guard store.browsingProfile == .regular else {
			requestConfirmation(for: host, kind: WebPermissionKind.location, decisionHandler: decisionHandler)
			return
		}

		if let siteSettingsStore = store.siteSettingsStore {
			let siteKey = SiteKey(host: host)
			Task {
				let decision = await siteSettingsStore.effectiveDecision(for: siteKey, type: PermissionType.location)
				if decision == .ask,
					let provider = self.store.websitePreferencesProvider {
					let legacy = mapLegacyPermission(provider.getPreferences(for: host).locationPermission)
					if legacy != .ask {
						await siteSettingsStore.setDecision(legacy, for: siteKey, type: PermissionType.location, source: .migrated)
						handlePermissionDecision(legacy, host: host, kind: WebPermissionKind.location, decisionHandler: decisionHandler)
						return
					}
				}
				handlePermissionDecision(decision, host: host, kind: WebPermissionKind.location, decisionHandler: decisionHandler)
			}
			return
		}

		guard let provider = store.websitePreferencesProvider else {
			decisionHandler(.prompt)
			return
		}
		let prefs = provider.getPreferences(for: host)
		switch prefs.locationPermission {
		case .allow:
			decisionHandler(.grant)
		case .deny:
			decisionHandler(.deny)
		case .ask:
			requestConfirmation(for: host, kind: WebPermissionKind.location, decisionHandler: decisionHandler)
		@unknown default:
			decisionHandler(.prompt)
		}
	}

	private func handlePermissionDecision(
		_ decision: PermissionDecision,
		host: String,
		kind: WebPermissionKind,
		decisionHandler: @escaping (WKPermissionDecision) -> Void
	) {
		switch decision {
		case .allow:
			decisionHandler(.grant)
		case .deny:
			decisionHandler(.deny)
		case .ask:
			requestConfirmation(for: host, kind: kind, decisionHandler: decisionHandler)
		@unknown default:
			decisionHandler(.prompt)
		}
	}

	private func mapLegacyPermission(_ setting: WebsitePreferences.PermissionSetting) -> PermissionDecision {
		switch setting {
		case .allow:
			return .allow
		case .deny:
			return .deny
		case .ask:
			return .ask
		@unknown default:
			return .ask
		}
	}

	// MARK: - Downloads

	@available(iOS 14.5, macOS 11.3, *)
	public func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
		download.delegate = store
		store.onDownloadDidStart?(download)
	}

	@available(iOS 14.5, macOS 11.3, *)
	public func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
		download.delegate = store
		store.onDownloadDidStart?(download)
	}

	@available(iOS 14.5, macOS 11.3, *)
	public func download(
		_ download: WKDownload,
		decideDestinationUsing response: URLResponse,
		suggestedFilename: String,
		completionHandler: @escaping @MainActor @Sendable (URL?) -> Void
	) {
		let destinationURL = store.onDownloadDecideDestination?(download, response, suggestedFilename)
			?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(suggestedFilename)
		completionHandler(destinationURL)
	}

	@available(iOS 14.5, macOS 11.3, *)
	public func downloadDidFinish(_ download: WKDownload) {
		store.onDownloadDidFinish?(download.originalRequest?.url)
	}

	@available(iOS 14.5, macOS 11.3, *)
	public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
		store.onDownloadDidFail?(error)
	}
}
