
public typealias Tab = TabModel
import Foundation
import BrowserCore

public enum CoreDefaults {
    public static let defaultHomeURLString = DefaultURLs.aboutBlank.absoluteString
}

/// Threading: Value type used as a pure data model.
/// `TabModel` is `Sendable` and can be used from any thread.
public struct TabModel: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var urlString: String
    public var title: String
    public var isLoading: Bool
    public var canGoBack: Bool
    public var canGoForward: Bool
    public var lifecycleState: TabLifecycleState = .active
    public var lastVisited: Date?

    public init(
        id: UUID = UUID(),
        urlString: String = CoreDefaults.defaultHomeURLString,
        title: String = "New Tab",
        isLoading: Bool = false,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        lifecycleState: TabLifecycleState = .active,
        lastVisited: Date? = nil
    ) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.isLoading = isLoading
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.lifecycleState = lifecycleState
        self.lastVisited = lastVisited
    }
}
