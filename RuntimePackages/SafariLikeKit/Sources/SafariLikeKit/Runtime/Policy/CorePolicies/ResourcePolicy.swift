import Foundation
import SafariLikeCoreKit
public struct ResourcePolicy: PolicyProviding {
    public let id: String = "core.resource"
    public let kind: PolicyProviderKind = .core
    public let priority: Int = 90
    private let trackerHosts: Set<String>
    public init() {
        self.trackerHosts = TrackerDenylist.load()
    }
    public func decideNavigation(_ ctx: NavigationContext) async -> PolicyDecision? { nil }
    public func decideResource(_ ctx: ResourceContext) async -> PolicyDecision? {
        if let host = ctx.url.host?.lowercased(), trackerHosts.contains(host) {
            return .cancel(reason: "tracker_host")
        }
        // Best-effort: add DNT header for subresources.
        if ctx.isThirdParty {
            return .modify(PolicyMutation(headersToAdd: ["DNT": "1"]))
        }
        return .allow
    }
    public func decidePrivacy(_ ctx: PrivacyContext) async -> PolicyDecision? { nil }
}
enum TrackerDenylist {
    static func load() -> Set<String> {
        // Placeholder denylist. If a bundled file exists in the future, prefer that.
        return [
            "doubleclick.net",
            "googlesyndication.com",
            "google-analytics.com",
            "facebook.com",
            "connect.facebook.net"
        ]
    }
}
