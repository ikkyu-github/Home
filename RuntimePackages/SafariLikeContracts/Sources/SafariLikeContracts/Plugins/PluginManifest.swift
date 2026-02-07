import Foundation

/// Compile-time / resource plugin manifest description.
///
/// This is intentionally WebKit-agnostic and encodes only metadata
/// + high-level permissions.
public struct PluginManifest: Codable, Sendable {
    public struct UserScript: Codable, Sendable {
        public enum Timing: String, Codable, Sendable {
            case atDocumentStart
            case afterDocumentEnd
        }

        public let id: String
        public let path: String
        public let timing: Timing
        public let allowedHosts: [String]?

        public init(
            id: String,
            path: String,
            timing: Timing,
            allowedHosts: [String]? = nil
        ) {
            self.id = id
            self.path = path
            self.timing = timing
            self.allowedHosts = allowedHosts
        }
    }

    public struct StyleSheet: Codable, Sendable {
        public let id: String
        public let path: String
        public let allowedHosts: [String]?

        public init(
            id: String,
            path: String,
            allowedHosts: [String]? = nil
        ) {
            self.id = id
            self.path = path
            self.allowedHosts = allowedHosts
        }
    }

    public let id: String
    public let name: String
    public let version: String

    /// Arbitrary permission strings; for Swift plugins this should
    /// map to `PluginPermission`, for resource plugins it may carry
    /// additional scopes.
    public let permissions: [String]?

    /// Optional list of JSON content rule list resource names.
    public let contentRuleLists: [String]?

    /// JavaScript user scripts to inject.
    public let userScripts: [UserScript]?

    /// CSS style sheets to inject.
    public let styleSheets: [StyleSheet]?

    public init(
        id: String,
        name: String,
        version: String,
        permissions: [String]? = nil,
        contentRuleLists: [String]? = nil,
        userScripts: [UserScript]? = nil,
        styleSheets: [StyleSheet]? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.permissions = permissions
        self.contentRuleLists = contentRuleLists
        self.userScripts = userScripts
        self.styleSheets = styleSheets
    }
}

public extension PluginManifest {
    /// Requested permissions parsed from the manifest's `permissions` strings.
    ///
    /// Unknown strings are ignored (and should be treated as not granted).
    var requestedPermissions: Set<PluginPermission> {
        guard let permissions else { return [] }
        return Set(permissions.compactMap { PluginPermission(permissionString: $0) })
    }

    func requests(_ permission: PluginPermission) -> Bool {
        requestedPermissions.contains(permission)
    }
}
