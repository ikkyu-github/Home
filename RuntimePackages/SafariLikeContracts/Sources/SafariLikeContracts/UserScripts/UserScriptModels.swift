import Foundation

// MARK: - Identity

/// Stable identifier for a user script.
public struct UserScriptID: Codable, Hashable, Sendable {
    public let uuid: UUID

    public init(uuid: UUID = UUID()) {
        self.uuid = uuid
    }
}

// MARK: - Profile

/// Profile boundary for user script execution.
///
/// Note: This intentionally avoids the `BrowsingProfile` name used in CoreKit.
public enum UserScriptProfile: String, Codable, Sendable, CaseIterable {
    case regular
    case `private`
}

// MARK: - Injection Time

public enum InjectionTime: String, Codable, Sendable, CaseIterable {
    case documentStart
    case documentEnd
}

// MARK: - Match Rules

public struct UserScriptMatchRules: Codable, Hashable, Sendable {
    /// Host patterns to include, e.g. `example.com` or `*.example.com`.
    ///
    /// Empty/nil means "match all hosts".
    public var includeHosts: [String]

    /// Host patterns to exclude.
    public var excludeHosts: [String]

    /// URL patterns to include (optional). Supports `*` wildcard glob matching.
    ///
    /// Empty/nil means "no URL include restriction".
    public var includeURLPatterns: [String]

    /// URL patterns to exclude. Supports `*` wildcard glob matching.
    public var excludeURLPatterns: [String]

    public init(
        includeHosts: [String] = [],
        excludeHosts: [String] = [],
        includeURLPatterns: [String] = [],
        excludeURLPatterns: [String] = []
    ) {
        self.includeHosts = includeHosts
        self.excludeHosts = excludeHosts
        self.includeURLPatterns = includeURLPatterns
        self.excludeURLPatterns = excludeURLPatterns
    }
}

// MARK: - Script

public struct UserScript: Codable, Hashable, Sendable, Identifiable {
    public var id: UserScriptID
    public var name: String
    public var description: String

    /// Inline source for user-created scripts.
    ///
    /// Privacy note: this is script source, not page content.
    public var sourceCode: String?

    /// Optional bundled resource name for built-in scripts.
    public var bundledResourceName: String?

    public var injectionTime: InjectionTime
    public var isEnabled: Bool

    /// Which profiles the script is allowed to execute in.
    public var profilesAllowed: Set<UserScriptProfile>

    public var matchRules: UserScriptMatchRules

    public init(
        id: UserScriptID = UserScriptID(),
        name: String,
        description: String,
        sourceCode: String? = nil,
        bundledResourceName: String? = nil,
        injectionTime: InjectionTime,
        isEnabled: Bool = true,
        profilesAllowed: Set<UserScriptProfile> = Set(UserScriptProfile.allCases),
        matchRules: UserScriptMatchRules = UserScriptMatchRules()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.sourceCode = sourceCode
        self.bundledResourceName = bundledResourceName
        self.injectionTime = injectionTime
        self.isEnabled = isEnabled
        self.profilesAllowed = profilesAllowed
        self.matchRules = matchRules
    }

    public var hasInlineSource: Bool {
        guard let sourceCode else { return false }
        return !sourceCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var hasBundledResource: Bool {
        guard let bundledResourceName else { return false }
        return !bundledResourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Policy

public struct ScriptPolicy: Codable, Hashable, Sendable {
    /// Master toggle for user scripts.
    public var globalEnabled: Bool

    /// Explicit opt-in to allow scripts in private browsing.
    ///
    /// Default is `false` (safe-by-default).
    public var privateModeEnabled: Bool

    /// Per-site override (keyed by `SiteKey.storageKey`), where value indicates whether
    /// scripts are enabled for that site.
    public var perSiteOverrides: [String: Bool]

    public init(
        globalEnabled: Bool = true,
        privateModeEnabled: Bool = false,
        perSiteOverrides: [String: Bool] = [:]
    ) {
        self.globalEnabled = globalEnabled
        self.privateModeEnabled = privateModeEnabled
        self.perSiteOverrides = perSiteOverrides
    }
}

#if DEBUG

public enum ScriptExecutionResult: String, Codable, Sendable {
    case success
    case failure
}

/// DEBUG-only execution record for diagnostics.
///
/// Privacy contract:
/// - Never include page content, form fields, or message payloads.
/// - `siteKey` should use `SiteKey.storageKey` (eTLD+1 approximation).
public struct ScriptExecutionRecord: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let scriptID: UserScriptID
    public let siteKey: String
    public let injectionTime: InjectionTime
    public let timestamp: Date
    public let result: ScriptExecutionResult
    public let errorSummary: String?

    public init(
        id: UUID = UUID(),
        scriptID: UserScriptID,
        siteKey: String,
        injectionTime: InjectionTime,
        timestamp: Date = Date(),
        result: ScriptExecutionResult,
        errorSummary: String? = nil
    ) {
        self.id = id
        self.scriptID = scriptID
        self.siteKey = siteKey
        self.injectionTime = injectionTime
        self.timestamp = timestamp
        self.result = result
        self.errorSummary = errorSummary
    }
}

#endif
