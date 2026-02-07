import Foundation

/// Snapshot of a tab's web navigation state.
///
/// Kept UI-agnostic so it can be used across modules without importing WebKit/UIKit.
public struct TabWebStoreState: Sendable, Equatable {
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
