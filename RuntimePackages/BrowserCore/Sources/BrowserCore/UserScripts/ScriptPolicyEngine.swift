import Foundation
import SafariLikeContracts

/// Computes which scripts are allowed for a given site/profile.
///
/// Deterministic and side-effect free.
public struct ScriptPolicyEngine: Sendable {
    public init() {}

    public func allowedScripts(
        scripts: [UserScript],
        policy: ScriptPolicy,
        siteKey: SiteKey,
        url: URL?,
        profile: UserScriptProfile
    ) -> [UserScript] {
        if policy.globalEnabled == false { return [] }
        if profile == .private, policy.privateModeEnabled == false { return [] }

        let siteOverride = policy.perSiteOverrides[siteKey.storageKey]
        if siteOverride == false { return [] }

        let host = (url?.host ?? siteKey.host).lowercased()
        let urlString = url?.absoluteString ?? ""

        let filtered = scripts.filter { script in
            guard script.isEnabled else { return false }
            guard script.profilesAllowed.contains(profile) else { return false }
            return matches(script: script, host: host, urlString: urlString)
        }

        return filtered.sorted(by: Self.scriptOrder)
    }

    // MARK: - Ordering

    public static func scriptOrder(_ a: UserScript, _ b: UserScript) -> Bool {
        if a.injectionTime != b.injectionTime {
            return a.injectionTime == .documentStart
        }

        let nameCmp = a.name.localizedCaseInsensitiveCompare(b.name)
        if nameCmp != .orderedSame {
            return nameCmp == .orderedAscending
        }

        return a.id.uuid.uuidString < b.id.uuid.uuidString
    }

    // MARK: - Matching

    private func matches(script: UserScript, host: String, urlString: String) -> Bool {
        let rules = script.matchRules

        if matchesAnyHostPattern(rules.excludeHosts, host: host) { return false }

        if !rules.includeHosts.isEmpty {
            guard matchesAnyHostPattern(rules.includeHosts, host: host) else { return false }
        }

        if matchesAnyGlobPattern(rules.excludeURLPatterns, value: urlString) { return false }

        if !rules.includeURLPatterns.isEmpty {
            guard matchesAnyGlobPattern(rules.includeURLPatterns, value: urlString) else { return false }
        }

        return true
    }

    private func matchesAnyHostPattern(_ patterns: [String], host: String) -> Bool {
        for p in patterns {
            if hostMatches(pattern: p, host: host) { return true }
        }
        return false
    }

    private func hostMatches(pattern: String, host: String) -> Bool {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return false }

        if trimmed == "*" { return true }

        // Support `*.example.com`.
        if trimmed.hasPrefix("*.") {
            let base = String(trimmed.dropFirst(2))
            if base.isEmpty { return false }
            return host == base || host.hasSuffix("." + base)
        }

        // Fallback: exact host match.
        return host == trimmed
    }

    private func matchesAnyGlobPattern(_ patterns: [String], value: String) -> Bool {
        for p in patterns {
            if globMatches(pattern: p, value: value) { return true }
        }
        return false
    }

    /// Very small glob matcher with `*` wildcard.
    ///
    /// - Note: This is intentionally not regex-based to keep behavior predictable.
    private func globMatches(pattern: String, value: String) -> Bool {
        let p = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if p.isEmpty { return false }
        if p == "*" { return true }

        // Split on `*` and require ordered containment.
        let parts = p.split(separator: "*", omittingEmptySubsequences: false).map(String.init)
        if parts.count == 1 { return value == p }

        var index = value.startIndex

        // Anchor start if pattern doesn't start with `*`.
        if let first = parts.first, !first.isEmpty, !p.hasPrefix("*") {
            guard value.hasPrefix(first) else { return false }
            index = value.index(value.startIndex, offsetBy: first.count)
        }

        // Middle parts.
        let middle = parts.dropFirst().dropLast()
        for part in middle {
            guard !part.isEmpty else { continue }
            guard let range = value.range(of: part, range: index..<value.endIndex) else { return false }
            index = range.upperBound
        }

        // Anchor end if pattern doesn't end with `*`.
        if let last = parts.last, !last.isEmpty, !p.hasSuffix("*") {
            return value.hasSuffix(last)
        }

        return true
    }
}
