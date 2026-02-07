import Foundation

/// Shared capability set for browser plugins.
///
/// This lives in SafariLikeContracts so both runtime (SafariLikeKit) and
/// policy/core layers can reason about what a plugin is allowed to do
/// without depending on any runtime/WebKit/UI types.
public enum PluginCapability: String, Codable, Hashable, Sendable {
    // Core navigation capabilities
    case navigationRead
    case navigationIntercept

    // Higher-level plugin categories (used for classification / auditing)
    case navigationObserver
    case analytics
    case uiAugmentation
    case experimental

    // Content-level capabilities
    case contentBlocking
    case contentScripts
    case contentInjection

    // Behavior and UI capabilities
    case websitePreferences
    case toolbarCommands

    // Library / session read capabilities
    case historyRead
    case bookmarksRead
    case tabObservation
}
