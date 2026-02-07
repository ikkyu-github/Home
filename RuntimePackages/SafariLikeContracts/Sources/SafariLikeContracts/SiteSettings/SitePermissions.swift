import Foundation

public enum PermissionType: String, Codable, CaseIterable, Sendable {
    case camera
    case microphone
    case location
    case notifications
    case popups
    case autoplay
    case javascript
}

public enum PermissionDecision: String, Codable, CaseIterable, Sendable {
    case allow
    case deny
    case ask
}

public enum PermissionSource: String, Codable, CaseIterable, Sendable {
    case user
    case `default`
    case enterprise
    case migrated
}

public struct SitePermissionRecord: Codable, Sendable, Equatable {
    public let siteKey: SiteKey
    public let permissionType: PermissionType
    public var decision: PermissionDecision
    public var updatedAt: Date
    public var source: PermissionSource

    public init(
        siteKey: SiteKey,
        permissionType: PermissionType,
        decision: PermissionDecision,
        updatedAt: Date = Date(),
        source: PermissionSource = .user
    ) {
        self.siteKey = siteKey
        self.permissionType = permissionType
        self.decision = decision
        self.updatedAt = updatedAt
        self.source = source
    }
}

public struct SiteSettingsSnapshot: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var globalDefaults: [PermissionType: PermissionDecision]
    public var records: [SitePermissionRecord]

    public init(
        schemaVersion: Int = 1,
        globalDefaults: [PermissionType: PermissionDecision] = PermissionType.defaultGlobalDefaults,
        records: [SitePermissionRecord] = []
    ) {
        self.schemaVersion = schemaVersion
        self.globalDefaults = globalDefaults
        self.records = records
    }
}

public extension PermissionType {
    static var defaultGlobalDefaults: [PermissionType: PermissionDecision] {
        var map: [PermissionType: PermissionDecision] = [:]
        for type in PermissionType.allCases {
            map[type] = type.safeFallbackDecision
        }
        return map
    }

    /// Conservative fallback when no explicit site record exists.
    var safeFallbackDecision: PermissionDecision {
        switch self {
        case .camera, .microphone, .location, .notifications:
            return .ask
        case .popups, .autoplay:
            return .deny
        case .javascript:
            return .allow
        }
    }
}

@MainActor
public protocol WebPermissionPrompting: AnyObject {
    /// Request an end-user decision for a given origin + permission.
    ///
    /// - Important: Implementations must avoid deadlocking navigation; this should be safe to await.
    func requestPermission(originHost: String, siteKey: SiteKey, type: PermissionType) async -> PermissionDecision
}
