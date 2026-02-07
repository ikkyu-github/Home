import Foundation
import Combine
import WebKit
import SafariLikeCoreKit
import SafariLikeUXKit
@MainActor
final class SplitBrowserNavigationDomain: ObservableObject {
	@Published private var _ping = false
	private weak var root: SplitBrowserViewModel?
	private weak var navigationService: NavigationService?
	// MARK: - Dependency Boundary
	init(root: SplitBrowserViewModel) {
		self.root = root
		// Capture navigationService from the ViewModel, which is the
		// single strong owner of NavigationService.
		self.navigationService = root.navigationService
	}
	// MARK: - Basic navigation (delegated to NavigationService)
	func goBack() {
		navigationService?.goBack()
	}
	func goForward() {
		navigationService?.goForward()
	}
	func reload() {
		navigationService?.reload()
	}
	func stopLoading() {
		navigationService?.stopLoading()
	}
	// MARK: - Open / Load helpers (delegated to NavigationService)
	/// Open a URL string, applying smart handling (scheme inference, search fallback).
	/// Uses TabWebStore.load to avoid creating extra WKWebView instances.
	func openURLString(_ string: String, force: Bool = false) {
		navigationService?.loadURLString(string, force: force)
	}
	/// Open a concrete URL directly (no normalization).
	func open(_ url: URL) {
		loadURL(url, force: false)
	}
	/// Commit the address currently shown in the omnibox.
	func commitAddress() {
		guard let rootVM = self.root else { return }
		rootVM.bar.submitAndDismissEditing(reason: "SplitBrowserNavigationDomain.commitAddress")
	}
	/// Load a concrete URL directly.
	func loadURL(_ url: URL, force: Bool = false) {
		navigationService?.loadURL(url, force: force)
	}
	/// Load a prepared URLRequest directly.
	func loadRequest(_ request: URLRequest, force: Bool = false) {
		navigationService?.loadRequest(request, force: force)
	}
}
