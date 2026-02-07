import Foundation

/// Browser profile used to select runtime behavior for tabs.
///
/// - `regular`: Standard browsing with persistent data.
/// - `private`: Private browsing similar to Safari's Private mode, using an
///   non-persistent data store.
public enum BrowsingProfile: String, Sendable {
    case regular
    case `private`
}
