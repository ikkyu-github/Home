import Foundation
import BrowserCore

/// Protocol boundary for reading tab navigation state.
///
/// This keeps SafariLikeCoreKit public APIs decoupled from BrowserCore types.
public protocol TabStateRepresentable: Sendable {
	var pageTitle: String? { get }
	var currentURL: URL? { get }
	var canGoBack: Bool { get }
	var canGoForward: Bool { get }
	var estimatedProgress: Double { get }
	var isLoading: Bool { get }
}

extension BrowserCore.TabWebStoreState: TabStateRepresentable {}

/// Snapshot of a tab's web navigation state.
public struct TabState: TabStateRepresentable, Sendable, Equatable {
	public var pageTitle: String?
	public var currentURL: URL?
	public var canGoBack: Bool
	public var canGoForward: Bool
	public var estimatedProgress: Double
	public var isLoading: Bool

	public init(
		pageTitle: String?,
		currentURL: URL?,
		canGoBack: Bool,
		canGoForward: Bool,
		estimatedProgress: Double,
		isLoading: Bool
	) {
		self.pageTitle = pageTitle
		self.currentURL = currentURL
		self.canGoBack = canGoBack
		self.canGoForward = canGoForward
		self.estimatedProgress = estimatedProgress
		self.isLoading = isLoading
	}
}
