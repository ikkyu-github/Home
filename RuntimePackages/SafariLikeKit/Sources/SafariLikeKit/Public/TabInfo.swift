import Foundation
import SafariLikeCoreKit
/// Public model for tab information in SafariLikeKit.
///
/// `TabInfo` is the **public facade** for tab state exposed to Apps. It provides
/// only safe, immutable information about a tab without exposing internal details
/// like view model state, loading flags, or navigation history.
///
/// ## Contract
/// - Use this type to display tab information in your UI
/// - Do NOT modify these properties directly (this type is immutable)
/// - Do NOT use this to manipulate tabs; use ``BrowserSceneSession`` public methods instead
///
/// ## Properties
/// - `id`: Unique identifier for the tab (stable across sessions if persisted)
/// - `title`: Display title (e.g., page title from HTML or domain name)
/// - `urlString`: Current URL (may be in progress if page is loading)
///
/// ## Typical Usage
/// ```swift
/// let tabs: [TabInfo] = session.tabs  // Get from session (when available)
/// for tab in tabs {
///     print("Tab: \(tab.title) - \(tab.urlString)")
/// }
/// ```
public struct TabInfo: Identifiable, Equatable {
    /// Unique identifier for this tab.
    public let id: UUID
    /// Display title of the tab (page title or domain).
    public let title: String
    /// Current URL being loaded or displayed.
    public let urlString: String
    /// Initialize a public tab info model.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (typically UUID)
    ///   - title: Display title for the tab
    ///   - urlString: URL string of the current page
    public init(
        id: UUID,
        title: String,
        urlString: String
    ) {
        self.id = id
        self.title = title
        self.urlString = urlString
    }
}
