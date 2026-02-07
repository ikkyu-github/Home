import Foundation
import BrowserCore

public enum SiteKeying {
    public static func siteKey(for url: URL) -> String {
        guard let host = url.host?.lowercased(), host.isEmpty == false else {
            return url.scheme ?? "unknown"
        }
        let parts = host.split(separator: ".")
        if parts.count >= 2 {
            return parts.suffix(2).joined(separator: ".")
        }
        return host
    }
}

public struct SiteHeuristics: Sendable {
    public let siteKey: String
    public let record: SiteHeuristicsStore.SiteRecord

    public init(siteKey: String, record: SiteHeuristicsStore.SiteRecord) {
        self.siteKey = siteKey
        self.record = record
    }

    public var isCrashy: Bool {
        (record.crashCountWindow >= 2) || (record.lastCrashAt.map { Date().timeIntervalSince($0) < 3600 } ?? false)
    }

    public var isHeavy: Bool {
        record.heavyMemoryScore >= 60
    }
}
