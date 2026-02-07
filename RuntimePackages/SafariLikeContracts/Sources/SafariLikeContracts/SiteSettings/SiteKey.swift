import Foundation

/// Canonical per-site key used for privacy-sensitive settings.
///
/// Best-effort normalization:
/// - Uses a lowercase host.
/// - Computes an eTLD+1 approximation when possible.
///
/// Note: eTLD+1 is non-trivial without a public suffix list. This implementation
/// intentionally provides a deterministic fallback and can be upgraded later.
public struct SiteKey: Codable, Hashable, Sendable {
    public let host: String
    public let eTLDPlus1: String?
    public let isIPLiteral: Bool

    /// Stable key for dictionaries / persistence.
    public var storageKey: String { (eTLDPlus1 ?? host) }

    public init(host: String, eTLDPlus1: String?, isIPLiteral: Bool) {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.host = normalizedHost
        self.eTLDPlus1 = eTLDPlus1
        self.isIPLiteral = isIPLiteral
    }

    public init(url: URL) {
        self.init(host: url.host ?? "")
    }

    public init(host: String) {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let ip = SiteKey.isIPLiteralHost(normalizedHost)
        let etld = ip ? nil : SiteKey.bestEffortETLDPlus1(normalizedHost)
        self.init(host: normalizedHost, eTLDPlus1: etld, isIPLiteral: ip)
    }

    private static func isIPLiteralHost(_ host: String) -> Bool {
        if host.isEmpty { return false }
        if host.contains(":") { return true } // best-effort IPv6

        // best-effort IPv4
        let parts = host.split(separator: ".")
        guard parts.count == 4 else { return false }
        for p in parts {
            guard let n = Int(p), (0...255).contains(n) else { return false }
        }
        return true
    }

    private static func bestEffortETLDPlus1(_ host: String) -> String? {
        let parts = host.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        // Naive but deterministic: last two labels.
        // Known parity gap vs real eTLD+1 for multi-part TLDs (e.g. co.uk).
        let last2 = parts.suffix(2)
        return last2.joined(separator: ".")
    }
}
