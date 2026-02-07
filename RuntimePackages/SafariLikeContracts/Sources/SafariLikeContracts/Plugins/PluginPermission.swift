import Foundation

/// User-granted permissions for plugins.
///
/// These are intentionally higher-level than internal hook/capability details.
/// A plugin may declare capabilities, but the host must additionally verify the
/// user has granted the corresponding permission before executing sensitive hooks
/// or allowing access to sensitive APIs.
public enum PluginPermission: String, Codable, CaseIterable, Hashable, Sendable {
    case navigationRead
    case navigationIntercept
    case contentScripts
    case contentBlocking
    case downloads
    case storage

    // Library / session read permissions
    case historyRead
    case bookmarksRead
    case tabObservation
}

public extension PluginPermission {
    /// Parse a permission string, supporting legacy/alias spellings.
    init?(permissionString: String) {
        switch permissionString {
        case "navigationRead":
            self = .navigationRead
        case "navigationIntercept":
            self = .navigationIntercept
        case "contentScripts":
            self = .contentScripts
        case "contentBlocking":
            self = .contentBlocking
        case "downloads":
            self = .downloads
        case "storage":
            self = .storage

        case "historyRead":
            self = .historyRead
        case "bookmarksRead":
            self = .bookmarksRead
        case "tabObservation":
            self = .tabObservation

        // Legacy / alias values observed in older manifests/tests.
        case "navigation":
            self = .navigationRead
        case "webview":
            self = .contentScripts
        default:
            return nil
        }
    }

    /// Best-effort mapping from an internal capability to a user-facing permission.
    ///
    /// Not all capabilities correspond to a permission; only security-sensitive ones do.
    init?(capability: PluginCapability) {
        switch capability {
        case .navigationRead:
            self = .navigationRead
        case .navigationIntercept:
            self = .navigationIntercept
        case .contentBlocking:
            self = .contentBlocking
        case .contentScripts, .contentInjection:
            self = .contentScripts
        case .historyRead:
            self = .historyRead
        case .bookmarksRead:
            self = .bookmarksRead
        case .tabObservation:
            self = .tabObservation
        case .navigationObserver, .analytics, .uiAugmentation, .experimental, .websitePreferences, .toolbarCommands:
            return nil
        }
    }
}
