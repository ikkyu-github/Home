import Foundation

/// Shared error model for the plugin system.
public enum PluginError: Error, LocalizedError, Sendable {
    case capabilityRequired(PluginCapability)
    case permissionRequired(PluginPermission)
    case sessionUnloaded
    case timeout
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .capabilityRequired(let cap):
            return "Plugin tried to use \(cap) without declaring it"
        case .permissionRequired(let perm):
            return "Plugin tried to use \(perm) without user permission"
        case .sessionUnloaded:
            return "Browser session was unloaded"
        case .timeout:
            return "Plugin operation timed out"
        case .invalidConfiguration(let reason):
            return "Invalid plugin configuration: \(reason)"
        @unknown default:
            return nil
        }
    }
}
