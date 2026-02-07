import Foundation

public enum PluginAuditAction: String, Codable, Sendable {
    case currentTabURL
    case navigationRequest
    case subscribeNavigationEvents
    case interceptNavigation
    case injectScript
    case removeScript

    // Library / session read
    case openTabs
    case recentHistory
    case bookmarks
}

public struct PluginAuditEvent: Codable, Sendable {
    public let timestamp: Date
    public let pluginID: String
    public let windowID: String
    public let tabID: String
    public let action: PluginAuditAction
    public let capability: PluginCapability
    public let requiredPermission: PluginPermission?
    public let url: String?

    public init(
        timestamp: Date = Date(),
        pluginID: String,
        windowID: String,
        tabID: String,
        action: PluginAuditAction,
        capability: PluginCapability,
        requiredPermission: PluginPermission?,
        url: String? = nil
    ) {
        self.timestamp = timestamp
        self.pluginID = pluginID
        self.windowID = windowID
        self.tabID = tabID
        self.action = action
        self.capability = capability
        self.requiredPermission = requiredPermission
        self.url = url
    }
}
